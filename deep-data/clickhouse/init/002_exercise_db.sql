CREATE TABLE IF NOT EXISTS exercise_db.muscle (
    id UInt32, name String, created_at DateTime64(3), updated_at DateTime64(3)
) ENGINE = ReplacingMergeTree(updated_at) ORDER BY id;

CREATE TABLE IF NOT EXISTS exercise_db.equipment (
    id UInt32, name String, created_at DateTime64(3), updated_at DateTime64(3)
) ENGINE = ReplacingMergeTree(updated_at) ORDER BY id;

CREATE TABLE IF NOT EXISTS exercise_db.exercise_category (
    id UInt32, name String, created_at DateTime64(3), updated_at DateTime64(3)
) ENGINE = ReplacingMergeTree(updated_at) ORDER BY id;

CREATE TABLE IF NOT EXISTS exercise_db.exercise (
    id                   UInt32,
    name                 String,
    force                LowCardinality(String),
    level                LowCardinality(String),
    mechanic             LowCardinality(String),
    instruction          String,
    photo                String,
    primary_muscle_ids   Array(UInt32),
    secondary_muscle_ids Array(UInt32),
    category_id          UInt32,
    equipment_id         UInt32,
    category_name        LowCardinality(String),
    equipment_name       LowCardinality(String),
    primary_muscle_names Array(String),
    created_at           DateTime64(3),
    updated_at           DateTime64(3)
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (equipment_id, level, id);
