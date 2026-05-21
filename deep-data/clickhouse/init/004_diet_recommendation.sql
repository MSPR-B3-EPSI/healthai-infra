CREATE TABLE IF NOT EXISTS diet_recommendation.disease (
    id UInt32, name String, created_at DateTime64(3), updated_at DateTime64(3)
) ENGINE = ReplacingMergeTree(updated_at) ORDER BY id;

CREATE TABLE IF NOT EXISTS diet_recommendation.allergy (
    id UInt32, name String, created_at DateTime64(3), updated_at DateTime64(3)
) ENGINE = ReplacingMergeTree(updated_at) ORDER BY id;

CREATE TABLE IF NOT EXISTS diet_recommendation.preferred_cuisine (
    id UInt32, name String, created_at DateTime64(3), updated_at DateTime64(3)
) ENGINE = ReplacingMergeTree(updated_at) ORDER BY id;

CREATE TABLE IF NOT EXISTS diet_recommendation.dietary_restriction (
    id UInt32, name String, created_at DateTime64(3), updated_at DateTime64(3)
) ENGINE = ReplacingMergeTree(updated_at) ORDER BY id;

CREATE TABLE IF NOT EXISTS diet_recommendation.diet_recommendation (
    id UInt32, name String, created_at DateTime64(3), updated_at DateTime64(3)
) ENGINE = ReplacingMergeTree(updated_at) ORDER BY id;

CREATE TABLE IF NOT EXISTS diet_recommendation.patient (
    id            UInt32,
    id_data_set   String,
    age           UInt8,
    gender        LowCardinality(String),
    allergy_ids   Array(UInt32),
    allergy_names Array(String),
    diseases      String,
    created_at    DateTime64(3),
    updated_at    DateTime64(3)
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY id;

CREATE TABLE IF NOT EXISTS diet_recommendation.metrics (
    id                  UInt32,
    patient_id          UInt32,
    weight_kg           Float32,
    height_cm           UInt16,
    bmi                 Float32,
    cholesterol_mg_dl   Float32,
    blood_pressure_mmhg Float32,
    glucose_mg_dl       Float32,
    created_at          DateTime64(3),
    updated_at          DateTime64(3)
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (patient_id, created_at, id);

CREATE TABLE IF NOT EXISTS diet_recommendation.exercises (
    id                      UInt32,
    patient_id              UInt32,
    weekly_exercise_hours   Float32,
    physical_activity_level LowCardinality(String),
    created_at              DateTime64(3),
    updated_at              DateTime64(3)
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (patient_id, created_at, id);

CREATE TABLE IF NOT EXISTS diet_recommendation.diets (
    id                               UInt32,
    daily_caloric_intake             UInt32,
    adherence_to_diet_plan           Float32,
    dietary_nutrient_imbalance_score Float32,
    patient_id                       UInt32,
    dietary_restriction_id           UInt32,
    preferred_cuisine_id             UInt32,
    diet_recommendation_id           UInt32,
    preferred_cuisine_name           LowCardinality(String),
    dietary_restriction_name         LowCardinality(String),
    diet_recommendation_name         LowCardinality(String),
    patient_age                      UInt8,
    patient_gender                   LowCardinality(String),
    created_at                       DateTime64(3),
    updated_at                       DateTime64(3)
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (preferred_cuisine_id, daily_caloric_intake, id);
