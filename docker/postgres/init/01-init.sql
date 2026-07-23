-- ==============================================================================
-- GDocument AI Platform
-- Infraestructura de Base de Datos - Producción
-- PostgreSQL + pgvector
-- ==============================================================================

-- ==========================================================================
-- INICIALIZACIÓN DE BASE DE DATOS
-- ==========================================================================

SELECT 'CREATE DATABASE gdocument_ai'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'gdocument_ai'
)\gexec

\c gdocument_ai

-- ==========================================================================
-- EXTENSIONES
-- ==========================================================================

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==========================================================================
-- TABLA PRINCIPAL
-- ==========================================================================

CREATE TABLE IF NOT EXISTS tickets (

    --------------------------------------------------------------------------
    -- Identificación
    --------------------------------------------------------------------------
    id                  VARCHAR(50) PRIMARY KEY,
    radicado            VARCHAR(50) UNIQUE NOT NULL,
    origen              VARCHAR(50) DEFAULT 'GDocument',

    --------------------------------------------------------------------------
    -- Cliente
    --------------------------------------------------------------------------
    empresa             VARCHAR(255),
    ciudad              VARCHAR(100),
    sede                VARCHAR(255),
    direccion           VARCHAR(255),
    area_ubicacion      VARCHAR(150),

    --------------------------------------------------------------------------
    -- Contacto
    --------------------------------------------------------------------------
    contacto_nombre     VARCHAR(150),
    contacto_celular    VARCHAR(50),

    --------------------------------------------------------------------------
    -- Equipo
    --------------------------------------------------------------------------
    marca               VARCHAR(100),
    modelo              VARCHAR(150),
    serial_equipo       VARCHAR(100),
    consumible          VARCHAR(150),

    --------------------------------------------------------------------------
    -- Requerimiento
    --------------------------------------------------------------------------
    tipo_requerimiento  VARCHAR(150),
    descripcion         TEXT,

    --------------------------------------------------------------------------
    -- Fechas del negocio
    --------------------------------------------------------------------------
    fecha_radicado      TIMESTAMP,
    fecha_cierre        TIMESTAMP,

    --------------------------------------------------------------------------
    -- Gestión
    --------------------------------------------------------------------------
    estado              VARCHAR(50) DEFAULT 'Pendiente',
    tecnico_asignado    VARCHAR(150),

    --------------------------------------------------------------------------
    -- Sistema RAG
    --------------------------------------------------------------------------
    documento_semantico TEXT,
    hash_documento      VARCHAR(64),
    embedding           VECTOR(768),

    --------------------------------------------------------------------------
    -- Metadatos
    --------------------------------------------------------------------------
    metadata            JSONB,

    --------------------------------------------------------------------------
    -- Auditoría de la plataforma
    --------------------------------------------------------------------------
    fecha_extraccion    TIMESTAMP,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_sync_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);

-- ==========================================================================
-- COMENTARIOS
-- ==========================================================================

COMMENT ON TABLE tickets IS
'Repositorio central de conocimiento del asistente inteligente';

COMMENT ON COLUMN tickets.documento_semantico IS
'Texto utilizado para generar embeddings';

COMMENT ON COLUMN tickets.hash_documento IS
'Hash SHA256 utilizado para detectar cambios semánticos';

COMMENT ON COLUMN tickets.embedding IS
'Vector generado mediante Gemini Embeddings';

COMMENT ON COLUMN tickets.metadata IS
'Información adicional del ticket en formato JSON';

COMMENT ON COLUMN tickets.fecha_radicado IS
'Fecha original de creación del ticket en GDocument';

COMMENT ON COLUMN tickets.fecha_cierre IS
'Fecha de cierre del ticket en GDocument';

COMMENT ON COLUMN tickets.fecha_extraccion IS
'Momento en que el Data Provider sincronizó el ticket';

-- ==========================================================================
-- ÍNDICES SQL
-- ==========================================================================

CREATE INDEX IF NOT EXISTS idx_ticket_radicado
ON tickets(radicado);

CREATE INDEX IF NOT EXISTS idx_ticket_empresa
ON tickets(empresa);

CREATE INDEX IF NOT EXISTS idx_ticket_estado
ON tickets(estado);

CREATE INDEX IF NOT EXISTS idx_ticket_serial
ON tickets(serial_equipo);

CREATE INDEX IF NOT EXISTS idx_ticket_tipo
ON tickets(tipo_requerimiento);

CREATE INDEX IF NOT EXISTS idx_ticket_fecha_radicado
ON tickets(fecha_radicado);

-- ==========================================================================
-- ÍNDICE VECTORIAL
-- ==========================================================================

CREATE INDEX IF NOT EXISTS idx_ticket_embedding
ON tickets
USING hnsw (embedding vector_cosine_ops);

-- ==========================================================================
-- ACTUALIZACIÓN AUTOMÁTICA
-- ==========================================================================

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS
$$
BEGIN
    NEW.updated_at := NOW();
    NEW.last_sync_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_timestamp ON tickets;

CREATE TRIGGER trg_update_timestamp
BEFORE UPDATE
ON tickets
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();