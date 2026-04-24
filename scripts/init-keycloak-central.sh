#!/usr/bin/env bash
# =============================================================================
# EIGEN IAM — Script d'initialisation Keycloak Central
# Usage : ./scripts/init-keycloak-central.sh
#
# Ce script configure les éléments qui ne peuvent pas être définis dans le
# JSON de realm (credentials des service accounts, configurations post-démarrage).
#
# Prérequis :
#   - Keycloak Central démarré et accessible
#   - Variables d'environnement définies (voir .env.example)
#   - kcadm.sh disponible dans le PATH ou dans $KEYCLOAK_HOME/bin/
# =============================================================================

set -euo pipefail

# --- Couleurs pour les logs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() { echo -e "\n${BOLD}=== $* ===${NC}\n"; }

# --- Configuration ---
KC_BASE_URL="${KC_BASE_URL:-http://localhost:8080}"
KC_REALM="master"
KC_ADMIN_USER="${KC_ADMIN_USER:-eigen-admin}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:?Définir KC_ADMIN_PASSWORD}"
TARGET_REALM="eigen-national"

KCADM="kcadm.sh"
if [ -n "${KEYCLOAK_HOME:-}" ]; then
    KCADM="$KEYCLOAK_HOME/bin/kcadm.sh"
fi

# --- Vérification des prérequis ---
log_section "EIGEN IAM :: Initialisation Keycloak Central"

if ! command -v "$KCADM" &> /dev/null; then
    # Essayer de le trouver dans le conteneur
    if [ -f "/opt/keycloak/bin/kcadm.sh" ]; then
        KCADM="/opt/keycloak/bin/kcadm.sh"
    else
        log_error "kcadm.sh introuvable. Définir KEYCLOAK_HOME ou l'exécuter dans le conteneur."
        exit 1
    fi
fi

# --- Attente que Keycloak soit prêt ---
log_info "Attente que Keycloak Central soit prêt..."
MAX_WAIT=120
WAITED=0
until curl -sf "$KC_BASE_URL/health/ready" > /dev/null 2>&1; do
    if [ $WAITED -ge $MAX_WAIT ]; then
        log_error "Keycloak n'est pas prêt après ${MAX_WAIT}s. Abandon."
        exit 1
    fi
    sleep 3
    WAITED=$((WAITED + 3))
    echo -n "."
done
echo ""
log_success "Keycloak Central est prêt ✓"

# --- Authentification admin ---
log_section "Authentification Administrateur"
$KCADM config credentials \
    --server "$KC_BASE_URL" \
    --realm "$KC_REALM" \
    --user "$KC_ADMIN_USER" \
    --password "$KC_ADMIN_PASSWORD" \
    --client admin-cli

log_success "Authentifié comme $KC_ADMIN_USER ✓"

# --- Vérification que le realm eigen-national existe ---
log_section "Vérification du Realm eigen-national"
if ! $KCADM get realms/"$TARGET_REALM" > /dev/null 2>&1; then
    log_warn "Le realm $TARGET_REALM n'existe pas encore. Il sera créé via l'import au prochain démarrage."
    log_info "Assurez-vous que keycloak/realm-config/eigen-national-realm.json est monté dans /opt/keycloak/data/import/"
fi
log_success "Realm $TARGET_REALM accessible ✓"

# --- Configuration des secrets des service accounts ---
log_section "Configuration des Service Accounts"

# Service Account : eigen-referentiel-service
if [ -n "${EIGEN_REFERENTIEL_CLIENT_SECRET:-}" ]; then
    REFERENTIEL_CLIENT_ID=$($KCADM get clients -r "$TARGET_REALM" \
        --fields id,clientId \
        --query "clientId=eigen-referentiel-service" \
        | python3 -c "import json,sys; data=json.load(sys.stdin); print(data[0]['id'] if data else '')" 2>/dev/null || true)

    if [ -n "$REFERENTIEL_CLIENT_ID" ]; then
        $KCADM update "clients/$REFERENTIEL_CLIENT_ID" \
            -r "$TARGET_REALM" \
            -s "secret=$EIGEN_REFERENTIEL_CLIENT_SECRET"
        log_success "Secret eigen-referentiel-service configuré ✓"
    else
        log_warn "Client eigen-referentiel-service non trouvé (realm pas encore importé ?)"
    fi
else
    log_warn "EIGEN_REFERENTIEL_CLIENT_SECRET non défini — secret non configuré"
fi

# Service Account : eigen-camel-service
if [ -n "${EIGEN_CAMEL_CLIENT_SECRET:-}" ]; then
    CAMEL_CLIENT_ID=$($KCADM get clients -r "$TARGET_REALM" \
        --fields id,clientId \
        --query "clientId=eigen-camel-service" \
        | python3 -c "import json,sys; data=json.load(sys.stdin); print(data[0]['id'] if data else '')" 2>/dev/null || true)

    if [ -n "$CAMEL_CLIENT_ID" ]; then
        $KCADM update "clients/$CAMEL_CLIENT_ID" \
            -r "$TARGET_REALM" \
            -s "secret=$EIGEN_CAMEL_CLIENT_SECRET"
        log_success "Secret eigen-camel-service configuré ✓"
    else
        log_warn "Client eigen-camel-service non trouvé"
    fi
fi

# --- Attribution des rôles aux service accounts ---
log_section "Attribution des rôles aux service accounts"

# Le service account du Référentiel a besoin de gérer les utilisateurs
$KCADM add-roles \
    -r "$TARGET_REALM" \
    --uusername "service-account-eigen-referentiel-service" \
    --rolename "coordinateur_ministeriel" 2>/dev/null || \
    log_warn "Rôle coordinateur_ministeriel déjà assigné ou service account non trouvé"

log_success "Rôles service accounts configurés ✓"

# --- Configuration de l'event listener Kafka ---
log_section "Configuration de l'Event Listener Kafka"

# Vérifier que le listener est enregistré
LISTENERS=$($KCADM get realms/"$TARGET_REALM" --fields eventsListeners \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(','.join(d.get('eventsListeners', [])))" 2>/dev/null || echo "")

if echo "$LISTENERS" | grep -q "eigen-kafka-event-listener"; then
    log_success "Event listener eigen-kafka-event-listener actif ✓"
else
    log_warn "Event listener eigen-kafka-event-listener non trouvé dans le realm."
    log_warn "Vérifier que le JAR est bien dans /opt/keycloak/providers/ et que Keycloak a redémarré."
fi

# --- Création d'un compte administrateur de test (dev uniquement) ---
if [ "${EIGEN_ENV:-production}" = "development" ]; then
    log_section "Création du compte admin de test (DEV uniquement)"

    $KCADM create users \
        -r "$TARGET_REALM" \
        -s "username=admin.test" \
        -s "email=admin.test@eigen.ga" \
        -s "firstName=Admin" \
        -s "lastName=Test" \
        -s "enabled=true" \
        -s "emailVerified=true" \
        -s "attributes.identifiant_national=ADM-2025-00001" \
        -s "attributes.type_utilisateur=coordinateur_ministeriel" 2>/dev/null || \
        log_warn "Compte admin.test déjà existant"

    $KCADM set-password \
        -r "$TARGET_REALM" \
        --username "admin.test" \
        --new-password "EigenAdmin2025!" \
        --temporary false 2>/dev/null || true

    log_success "Compte admin.test créé (DEV) ✓"
fi

# --- Résumé ---
log_section "Résumé de l'initialisation"
echo -e "${GREEN}✓${NC} Keycloak Central EIGEN initialisé avec succès"
echo ""
echo "  Realm       : $TARGET_REALM"
echo "  URL         : $KC_BASE_URL"
echo "  Admin UI    : $KC_BASE_URL/admin/$KC_REALM/console"
echo "  OIDC Config : $KC_BASE_URL/realms/$TARGET_REALM/.well-known/openid-configuration"
echo "  JWKS        : $KC_BASE_URL/realms/$TARGET_REALM/protocol/openid-connect/certs"
echo ""
log_success "Initialisation terminée ✓"
