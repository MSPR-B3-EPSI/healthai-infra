-- raw food (1 ligne CSV = 1 ligne ici)
CREATE TABLE IF NOT EXISTS daily_food.raw_food (
    food_item        String,
    category         String,
    calories         UInt32,
    protein_g        Float32,
    carbohydrates_g  Float32,
    fat_g            Float32,
    fiber_g          Float32,
    sugars_g         Float32,
    sodium_mg        UInt32,
    cholesterol_mg   UInt32,
    meal_type        String,
    water_intake_ml  UInt32,
    _ingested_at     DateTime DEFAULT now()
) ENGINE = MergeTree() ORDER BY tuple();

-- raw diet
CREATE TABLE IF NOT EXISTS diet_recommendation.raw_diet (
    patient_id_str                    String,
    age                               UInt8,
    gender                            String,
    weight_kg                         Float32,
    height_cm                         UInt16,
    bmi                               Float32,
    disease_type                      String,
    severity                          String,
    physical_activity_level           String,
    daily_caloric_intake              UInt32,
    cholesterol_mg_dl                 Float32,
    blood_pressure_mmhg               Float32,
    glucose_mg_dl                     Float32,
    dietary_restrictions              String,
    allergies                         String,
    preferred_cuisine                 String,
    weekly_exercise_hours             Float32,
    adherence_to_diet_plan            Float32,
    dietary_nutrient_imbalance_score  Float32,
    diet_recommendation               String,
    _ingested_at                      DateTime DEFAULT now()
) ENGINE = MergeTree() ORDER BY tuple();

-- raw exercise
CREATE TABLE IF NOT EXISTS exercise_db.raw_exercise (
    id_str            String,
    name              String,
    force             String,
    level             String,
    mechanic          String,
    equipment         String,
    category          String,
    primary_muscles   Array(String),
    secondary_muscles Array(String),
    instructions      Array(String),
    images            Array(String),
    _ingested_at      DateTime DEFAULT now()
) ENGINE = MergeTree() ORDER BY tuple();


-- ============================================
-- workout_session : raw tables
-- ============================================

-- Source 1 : CSV externe (1 ligne plate = 1 session avec tout)
CREATE TABLE IF NOT EXISTS workout_session.raw_csv (
    age                          UInt8,
    gender                       String,
    weight_kg                    Float32,
    height_m                     Float32,
    max_bpm                      UInt16,
    avg_bpm                      UInt16,
    resting_bpm                  UInt16,
    session_duration_hours       Float32,
    calories_burned              Float32,
    workout_type                 String,
    fat_percentage               Float32,
    water_intake_liters          Float32,
    workout_frequency_days_week  UInt8,
    experience_level             UInt8,
    bmi                          Float32,
    _ingested_at                 DateTime DEFAULT now()
) ENGINE = MergeTree() ORDER BY tuple();

-- ============================================
-- workout_session : raw tables (simplifié)
-- ============================================

-- Source 1 : CSV externe (Kaggle)
CREATE TABLE IF NOT EXISTS workout_session.raw_csv (
    age                          UInt8,
    gender                       String,
    weight_kg                    Float32,
    height_m                     Float32,
    max_bpm                      UInt16,
    avg_bpm                      UInt16,
    resting_bpm                  UInt16,
    session_duration_hours       Float32,
    calories_burned              Float32,
    workout_type                 String,
    fat_percentage               Float32,
    water_intake_liters          Float32,
    workout_frequency_days_week  UInt8,
    experience_level             UInt8,
    bmi                          Float32,
    _ingested_at                 DateTime DEFAULT now()
) ENGINE = MergeTree() ORDER BY tuple();

-- Source 2 : dump API (même schéma que raw_csv puisque l'API retourne du CSV plat)
CREATE TABLE IF NOT EXISTS workout_session.raw_api (
    age                          UInt8,
    gender                       String,
    weight_kg                    Float32,
    height_m                     Float32,
    max_bpm                      UInt16,
    avg_bpm                      UInt16,
    resting_bpm                  UInt16,
    session_duration_hours       Float32,
    calories_burned              Float32,
    workout_type                 String,
    fat_percentage               Float32,
    water_intake_liters          Float32,
    workout_frequency_days_week  UInt8,
    experience_level             UInt8,
    bmi                          Float32,
    _ingested_at                 DateTime DEFAULT now()
) ENGINE = MergeTree() ORDER BY tuple();
