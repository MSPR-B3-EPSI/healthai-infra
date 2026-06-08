-- ============================================
-- 0) Reset des tables clean (full refresh)
-- ============================================
TRUNCATE TABLE workout_session.session;
TRUNCATE TABLE workout_session.workout_type;

-- ============================================
-- 1) CSV externe (depuis lake/raw/external/) → raw_csv
-- ============================================
TRUNCATE TABLE workout_session.raw_csv;

INSERT INTO workout_session.raw_csv
(age, gender, weight_kg, height_m, max_bpm, avg_bpm, resting_bpm,
 session_duration_hours, calories_burned, workout_type, fat_percentage,
 water_intake_liters, workout_frequency_days_week, experience_level, bmi)
SELECT
    "Age"                              AS age,
    "Gender"                           AS gender,
    "Weight (kg)"                      AS weight_kg,
    "Height (m)"                       AS height_m,
    "Max_BPM"                          AS max_bpm,
    "Avg_BPM"                          AS avg_bpm,
    "Resting_BPM"                      AS resting_bpm,
    "Session_Duration (hours)"         AS session_duration_hours,
    "Calories_Burned"                  AS calories_burned,
    "Workout_Type"                     AS workout_type,
    "Fat_Percentage"                   AS fat_percentage,
    "Water_Intake (liters)"            AS water_intake_liters,
    "Workout_Frequency (days/week)"    AS workout_frequency_days_week,
    "Experience_Level"                 AS experience_level,
    "BMI"                              AS bmi
FROM s3(
    minio_lake,
    filename = 'raw/external/workout_session/_latest.csv',
    format   = 'CSVWithNames',
    structure = '"Age" UInt8, "Gender" String, "Weight (kg)" Float32, "Height (m)" Float32,
                 "Max_BPM" UInt16, "Avg_BPM" UInt16, "Resting_BPM" UInt16,
                 "Session_Duration (hours)" Float32, "Calories_Burned" Float32,
                 "Workout_Type" String, "Fat_Percentage" Float32,
                 "Water_Intake (liters)" Float32, "Workout_Frequency (days/week)" UInt8,
                 "Experience_Level" UInt8, "BMI" Float32'
)
SETTINGS
    input_format_allow_errors_num = 100,
    input_format_allow_errors_ratio = 0.1
;

-- ============================================
-- 2) Dump API (depuis lake/raw/api/) → raw_api
-- ============================================
TRUNCATE TABLE workout_session.raw_api;

INSERT INTO workout_session.raw_api
(age, gender, weight_kg, height_m, max_bpm, avg_bpm, resting_bpm,
 session_duration_hours, calories_burned, workout_type, fat_percentage,
 water_intake_liters, workout_frequency_days_week, experience_level, bmi)
SELECT *
FROM s3(
    minio_lake,
    filename = 'raw/api/workout_session/_latest.csv',
    format   = 'CSVWithNames',
    structure = 'age UInt8, gender String, weight_kg Float32, height_m Float32,
                 max_bpm UInt16, avg_bpm UInt16, resting_bpm UInt16,
                 session_duration_hours Float32, calories_burned Float32,
                 workout_type String, fat_percentage Float32,
                 water_intake_liters Float32, workout_frequency_days_week UInt8,
                 experience_level UInt8, bmi Float32'
)
SETTINGS
    input_format_allow_errors_num = 100,
    input_format_allow_errors_ratio = 0.1
;

-- ============================================
-- 3) Dimension workout_type : union des types des 2 sources
-- ============================================
INSERT INTO workout_session.workout_type (id, name, created_at, updated_at)
SELECT
    toUInt32(cityHash64(name) % 4294967295) AS id,
    name,
    now64(3),
    now64(3)
FROM (
    SELECT DISTINCT workout_type AS name FROM workout_session.raw_csv WHERE workout_type != ''
    UNION DISTINCT
    SELECT DISTINCT workout_type AS name FROM workout_session.raw_api WHERE workout_type != ''
);

-- ============================================
-- 4) Table de faits : INSERT depuis les 2 sources avec tag `source`
-- ============================================

-- Sessions externes (CSV Kaggle)
INSERT INTO workout_session.session
SELECT
    cityHash64('csv', rowNumberInAllBlocks(), age, gender, workout_type, calories_burned) AS id,
    'external_csv' AS source,
    0 AS member_id,
    0 AS snapshot_id,
    age, gender, height_m, weight_kg, bmi, fat_percentage,
    experience_level, workout_frequency_days_week AS workout_frequency_per_week,
    toUInt32(cityHash64(workout_type) % 4294967295) AS workout_type_id,
    workout_type AS workout_type_name,
    session_duration_hours AS duration_hours,
    calories_burned AS calories,
    avg_bpm, max_bpm, resting_bpm, water_intake_liters,
    NULL AS started_at,
    now64(3) AS created_at,
    now64(3) AS updated_at
FROM workout_session.raw_csv;

-- Sessions API (dump tracking-api)
INSERT INTO workout_session.session
SELECT
    cityHash64('api', rowNumberInAllBlocks(), age, gender, workout_type, calories_burned) AS id,
    'api' AS source,
    0 AS member_id,
    0 AS snapshot_id,
    age, gender, height_m, weight_kg, bmi, fat_percentage,
    experience_level, workout_frequency_days_week AS workout_frequency_per_week,
    toUInt32(cityHash64(workout_type) % 4294967295) AS workout_type_id,
    workout_type AS workout_type_name,
    session_duration_hours AS duration_hours,
    calories_burned AS calories,
    avg_bpm, max_bpm, resting_bpm, water_intake_liters,
    NULL AS started_at,
    now64(3) AS created_at,
    now64(3) AS updated_at
FROM workout_session.raw_api;
