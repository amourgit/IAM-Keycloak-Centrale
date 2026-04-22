-- =============================================================================
-- EIGEN IAM :: Initialisation PostgreSQL — Keycloak Central
-- Script exécuté automatiquement au premier démarrage du conteneur PostgreSQL.
-- =============================================================================

-- Extension UUID pour génération d'identifiants
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Extension pour la recherche full-text en cas d'audit
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Schéma dédié à l'audit EIGEN (séparé du schéma Keycloak natif)
CREATE SCHEMA IF NOT EXISTS eigen_audit;

-- -----------------------------------------------------------------------------
-- Table d'audit des événements critiques de sécurité
-- Keycloak écrit dans ses propres tables, mais on maintient une trace
-- supplémentaire pour la conformité et l'analyse réglementaire gabonaise.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS eigen_audit.evenements_securite (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type_evenement  VARCHAR(100) NOT NULL,
    user_id         VARCHAR(36),
    realm_id        VARCHAR(36),
    client_id       VARCHAR(255),
    ip_address      INET,
    details         JSONB,
    horodatage      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_evenements_user_id
    ON eigen_audit.evenements_securite (user_id);

CREATE INDEX IF NOT EXISTS idx_evenements_type
    ON eigen_audit.evenements_securite (type_evenement);

CREATE INDEX IF NOT EXISTS idx_evenements_horodatage
    ON eigen_audit.evenements_securite (horodatage DESC);

-- -----------------------------------------------------------------------------
-- Table de log des synchronisations vers les établissements
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS eigen_audit.synchronisations (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id_national    VARCHAR(36) NOT NULL,
    etablissement_code  VARCHAR(20) NOT NULL,
    type_operation      VARCHAR(50) NOT NULL,
    statut              VARCHAR(20) NOT NULL DEFAULT 'en_attente',
    details             JSONB,
    erreur              TEXT,
    cree_le             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    traite_le           TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sync_user_national
    ON eigen_audit.synchronisations (user_id_national);

CREATE INDEX IF NOT EXISTS idx_sync_etablissement
    ON eigen_audit.synchronisations (etablissement_code);

CREATE INDEX IF NOT EXISTS idx_sync_statut
    ON eigen_audit.synchronisations (statut);

-- -----------------------------------------------------------------------------
-- Vue pour monitoring : tentatives de connexion échouées (30 dernières minutes)
-- Utilisée par le système de détection d'intrusion EIGEN
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW eigen_audit.tentatives_echec_recentes AS
SELECT
    ip_address,
    COUNT(*) as nb_echecs,
    MAX(horodatage) as derniere_tentative
FROM eigen_audit.evenements_securite
WHERE
    type_evenement = 'LOGIN_ERROR'
    AND horodatage > NOW() - INTERVAL '30 minutes'
GROUP BY ip_address
HAVING COUNT(*) >= 3
ORDER BY nb_echecs DESC;

-- Log d'initialisation
INSERT INTO eigen_audit.evenements_securite
    (type_evenement, details)
VALUES
    ('SYSTEME_INITIALISE', '{"message": "Base PostgreSQL Keycloak Central initialisée", "composant": "IAM-Keycloak-Centrale", "version": "1.0.0"}');
