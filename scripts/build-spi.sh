#!/usr/bin/env bash
# =============================================================================
# EIGEN IAM — Build du SPI Kafka Event Listener
# Produit le JAR à déployer dans /opt/keycloak/providers/
#
# Usage : ./scripts/build-spi.sh [--deploy]
#   --deploy : copie le JAR dans le répertoire de déploiement local
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SPI_DIR="$ROOT_DIR/keycloak/extensions/eigen-kafka-listener"
OUTPUT_DIR="$ROOT_DIR/keycloak/extensions"

log_info()    { echo "[INFO]  $*"; }
log_success() { echo "[OK]    $*"; }
log_error()   { echo "[ERROR] $*" >&2; }

log_info "=== EIGEN IAM :: Build SPI Kafka Event Listener ==="
log_info "Répertoire SPI : $SPI_DIR"

# Vérification Maven
if ! command -v mvn &> /dev/null; then
    log_error "Maven non trouvé. Installer Maven 3.8+ et réessayer."
    exit 1
fi

log_info "Version Maven : $(mvn --version | head -1)"

# Build Maven
cd "$SPI_DIR"
log_info "Build Maven en cours..."
mvn clean package -DskipTests -q

# Localiser le JAR produit
JAR_FILE=$(find "$SPI_DIR/target" -name "eigen-kafka-listener-*.jar" \
    ! -name "*-sources.jar" \
    ! -name "*-javadoc.jar" \
    | head -1)

if [ -z "$JAR_FILE" ]; then
    log_error "JAR non trouvé après le build. Vérifier les logs Maven."
    exit 1
fi

log_success "JAR produit : $JAR_FILE"
JAR_NAME=$(basename "$JAR_FILE")

# Copier dans le répertoire de déploiement
cp "$JAR_FILE" "$OUTPUT_DIR/$JAR_NAME"
log_success "JAR copié dans $OUTPUT_DIR/$JAR_NAME"

# Option --deploy : déploiement dans un conteneur Keycloak local en cours d'exécution
if [[ "${1:-}" == "--deploy" ]]; then
    CONTAINER="${KC_CONTAINER_NAME:-eigen-keycloak-central}"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        log_info "Déploiement dans le conteneur Docker $CONTAINER..."
        docker cp "$OUTPUT_DIR/$JAR_NAME" "$CONTAINER:/opt/keycloak/providers/"
        log_info "Redémarrage de Keycloak pour charger le nouveau SPI..."
        docker restart "$CONTAINER"
        log_success "SPI déployé et Keycloak redémarré ✓"
    else
        log_error "Conteneur $CONTAINER non trouvé. Démarrer le stack avec 'docker-compose up -d' d'abord."
        exit 1
    fi
fi

echo ""
log_success "Build terminé !"
echo ""
echo "Pour déployer manuellement dans Keycloak :"
echo "  cp $OUTPUT_DIR/$JAR_NAME /opt/keycloak/providers/"
echo "  # Puis redémarrer Keycloak"
echo ""
echo "Avec Docker Compose :"
echo "  Le JAR est monté automatiquement via le volume ./keycloak/extensions dans docker-compose.yml"
echo "  Reconstruire l'image avec : docker-compose up -d --force-recreate keycloak-central"
