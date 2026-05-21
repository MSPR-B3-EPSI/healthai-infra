-- Dimension workout_type (référentiel partagé entre les 2 sources)
CREATE TABLE IF NOT EXISTS workout_session.workout_type (
    id         UInt32,
    name       String,
    created_at DateTime64(3),
    updated_at DateTime64(3)
) ENGINE = ReplacingMergeTree(updated_at) ORDER BY id;

-- Table de faits dénormalisée (option B)
-- 1 ligne = 1 session, avec toutes les caractéristiques aplaties
CREATE TABLE IF NOT EXISTS workout_session.session (
    id              UInt64,
    
    -- traçabilité source
    source          LowCardinality(String),       -- 'api' ou 'external_csv'
    
    -- caractéristiques du sujet (membre + snapshot dénormalisés)
    member_id       UInt32,                        -- 0 si CSV (pas de notion de membre)
    snapshot_id     UInt32,                        -- 0 si CSV
    age             UInt8,
    gender          LowCardinality(String),
    height_m        Float32,
    weight_kg       Float32,
    bmi             Float32,
    fat_percentage  Float32,
    experience_level UInt8,                        -- 1, 2, 3
    workout_frequency_per_week UInt8,
    
    -- mesures de la session
    workout_type_id    UInt32,
    workout_type_name  LowCardinality(String),     -- dénormalisé
    duration_hours     Float32,
    calories           Float32,
    avg_bpm            UInt16,
    max_bpm            UInt16,
    resting_bpm        UInt16,
    water_intake_liters Float32,
    
    -- temporalité
    started_at         Nullable(DateTime64(3)),    -- NULL pour les sessions CSV
    created_at         DateTime64(3),              -- date d'ingestion (toujours rempli)
    updated_at         DateTime64(3)
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (source, workout_type_id, id);
