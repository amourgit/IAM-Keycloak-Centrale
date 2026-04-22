# EIGEN IAM — Keycloak Central

> **Système National d'Identité — Ministère de l'Enseignement Supérieur, République Gabonaise**

Keycloak Central est le moteur d'authentification national du système EIGEN. Il constitue la source d'autorité absolue sur l'existence de toute personne dans le système éducatif gabonais.

---

## Architecture

```
Internet
    │
    ▼
[Traefik] (TLS)
    │
    ▼
[Keycloak Central]          realm: eigen-national
├── SPI: eigen-kafka-event-listener  → publie sur Kafka
├── Thème: eigen-central             → UI brandée EIGEN
├── Realm: eigen-national            → configuration complète
└── JWKS: /realms/eigen-national/protocol/openid-connect/certs
    │
    ▼
[PostgreSQL]                 persistance Keycloak
    │
    ▼
[Kafka]                      transport événements EIGEN
    ├── eigen.national.compte.cree
    ├── eigen.national.compte.modifie
    ├── eigen.national.session.ouverte
    ├── eigen.national.session.fermee
    ├── eigen.national.authentification.echec
    └── eigen.national.audit
```

---

## Composants du repository

```
IAM-Keycloak-Centrale/
├── docker-compose.yml              Orchestration complète (KC + PG + Kafka)
├── Dockerfile                      Image Keycloak préconfigurée EIGEN
├── .env.example                    Template de configuration
├── keycloak/
│   ├── realm-config/
│   │   └── eigen-national-realm.json   Configuration complète du realm
│   ├── themes/
│   │   └── eigen-central/              Thème visuel EIGEN (login, email)
│   └── extensions/
│       └── eigen-kafka-listener/       SPI Kafka (Maven/Java)
│           ├── pom.xml
│           └── src/main/java/ga/eigen/keycloak/listener/
│               ├── EigenKafkaEventListener.java        Listener principal
│               ├── EigenKafkaEventListenerFactory.java Factory + lifecycle KafkaProducer
│               └── EigenKafkaEventListenerNoOp.java    Mode dégradé (Kafka down)
├── postgres/
│   └── init/
│       └── 01-init-eigen-audit.sql     Schéma d'audit PostgreSQL
└── scripts/
    ├── init-keycloak-central.sh        Initialisation post-démarrage
    └── build-spi.sh                    Build du JAR SPI
```

---

## Démarrage rapide

### Prérequis
- Docker 24+ et Docker Compose v2
- Java 17+ et Maven 3.8+ (pour le build SPI uniquement)
- 4 Go RAM minimum pour le stack complet

### 1. Configuration

```bash
cp .env.example .env
# Éditer .env avec vos valeurs (mots de passe, hostname, etc.)
```

### 2. Build du SPI Kafka

```bash
./scripts/build-spi.sh
```

### 3. Démarrage

```bash
docker-compose up -d
```

### 4. Vérification

```bash
# Santé Keycloak
curl http://localhost:8080/health/ready

# Découverte OIDC
curl http://localhost:8080/realms/eigen-national/.well-known/openid-configuration

# JWKS (clés publiques de vérification)
curl http://localhost:8080/realms/eigen-national/protocol/openid-connect/certs
```

### 5. Initialisation post-démarrage

```bash
./scripts/init-keycloak-central.sh
```

---

## Configuration du Realm `eigen-national`

### Clients configurés

| Client | Type | Usage |
|--------|------|-------|
| `portail-eigen` | Public OIDC | Portail national — flux Authorization Code + PKCE |
| `eigen-referentiel-service` | Confidential | Service account — provisioning national |
| `eigen-camel-service` | Confidential | Service account — imports CSV/SFTP |

### Attributs custom utilisateur

| Attribut | Format | Description |
|----------|--------|-------------|
| `identifiant_national` | `ETU-2025-00412` | Identifiant immuable EIGEN |
| `type_utilisateur` | `etudiant\|enseignant\|personnel_admin\|...` | Type dans le système |
| `date_naissance` | `YYYY-MM-DD` | Date de naissance |
| `sexe` | `M\|F` | Sexe |
| `nationalite` | Texte libre | Nationalité |

### Scope `eigen-national-claims`

Injecte dans les tokens JWT :
- `identifiant_national` → claim `identifiant_national`
- `type_utilisateur` → claim `type_utilisateur`
- `sexe` → claim `sexe`
- `nationalite` → claim `nationalite`

### Topics Kafka publiés

| Topic | Événement déclencheur |
|-------|----------------------|
| `eigen.national.compte.cree` | Création d'un utilisateur (API Admin) |
| `eigen.national.compte.modifie` | Modification d'un utilisateur (API Admin) |
| `eigen.national.compte.desactive` | Suppression/désactivation (API Admin) |
| `eigen.national.session.ouverte` | Connexion réussie |
| `eigen.national.session.fermee` | Déconnexion |
| `eigen.national.authentification.echec` | Échec de connexion |
| `eigen.national.audit` | Tous les événements importants |

---

## SPI Kafka Event Listener

### Build

```bash
cd keycloak/extensions/eigen-kafka-listener
mvn clean package -DskipTests
# → target/eigen-kafka-listener-1.0.0.jar
```

### Déploiement

Le JAR est monté automatiquement via `docker-compose.yml` dans `/opt/keycloak/providers/`.

Pour un déploiement hot (sans redémarrage du conteneur, mode développement) :

```bash
./scripts/build-spi.sh --deploy
```

### Variables d'environnement SPI

| Variable | Description | Défaut |
|----------|-------------|--------|
| `EIGEN_KAFKA_BOOTSTRAP` | Brokers Kafka (`host:port`) | `localhost:9092` |
| `EIGEN_KAFKA_TOPIC_PREFIX` | Préfixe des topics | `eigen.national` |
| `EIGEN_ETABLISSEMENT_CODE` | Code établissement | `NATIONAL` |

---

## Sécurité

- **Aucun mot de passe en clair** dans le code ou les fichiers committés
- Les secrets sont gérés via HashiCorp Vault en production
- Le fichier `.env` est dans `.gitignore`
- La politique de mot de passe impose 12 caractères minimum avec complexité
- La protection brute-force est activée (5 tentatives → lockout 15 min)
- Les headers de sécurité HTTP sont configurés (CSP, HSTS, X-Frame-Options)

---

## Licence et propriété intellectuelle

Ce système est la propriété exclusive du Ministère de l'Enseignement Supérieur de la République Gabonaise. Toute reproduction, distribution ou utilisation sans autorisation expresse est interdite.

© 2025 EIGEN — Tous droits réservés.
