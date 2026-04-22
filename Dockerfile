# =============================================================================
# EIGEN IAM — Dockerfile :: Keycloak Central
# Image Keycloak préconfigurée avec les extensions et thèmes EIGEN.
#
# Build : docker build -t eigen/keycloak-central:1.0.0 .
# =============================================================================

# Stage 1 : Build du SPI Kafka (Maven)
FROM maven:3.9.6-eclipse-temurin-17 AS spi-builder

WORKDIR /build

# Copier le POM en premier pour profiter du cache Maven
COPY keycloak/extensions/eigen-kafka-listener/pom.xml .
RUN mvn dependency:go-offline -q

# Copier les sources et compiler
COPY keycloak/extensions/eigen-kafka-listener/src ./src
RUN mvn clean package -DskipTests -q

# Vérification
RUN ls -la target/*.jar

# =============================================================================
# Stage 2 : Image Keycloak finale
# =============================================================================
FROM quay.io/keycloak/keycloak:24.0.5 AS keycloak-configured

# Métadonnées EIGEN
LABEL maintainer="EIGEN IAM Team <iam@eigen.ga>"
LABEL org.opencontainers.image.title="EIGEN Keycloak Central"
LABEL org.opencontainers.image.description="Keycloak Central EIGEN — Système National d'Identité Gabonais"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.vendor="Ministère de l'Enseignement Supérieur, République Gabonaise"
LABEL eigen.component="keycloak-central"
LABEL eigen.tier="national"

# Copier le SPI Kafka compilé
COPY --from=spi-builder /build/target/eigen-kafka-listener-*.jar /opt/keycloak/providers/

# Copier le thème EIGEN Central
COPY keycloak/themes/eigen-central /opt/keycloak/themes/eigen-central

# Copier la configuration de realm (import automatique au démarrage)
COPY keycloak/realm-config /opt/keycloak/data/import

# Pré-build Keycloak avec les configurations statiques
# (optimise le temps de démarrage en production)
RUN /opt/keycloak/bin/kc.sh build \
    --db=postgres \
    --features=token-exchange,admin-fine-grained-authz,declarative-user-profile \
    --health-enabled=true \
    --metrics-enabled=true

# Point d'entrée standard Keycloak
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized", "--import-realm"]
