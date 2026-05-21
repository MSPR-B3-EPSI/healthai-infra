-- 0) Reset
TRUNCATE TABLE diet_recommendation.raw_diet;
TRUNCATE TABLE diet_recommendation.disease;
TRUNCATE TABLE diet_recommendation.allergy;
TRUNCATE TABLE diet_recommendation.preferred_cuisine;
TRUNCATE TABLE diet_recommendation.dietary_restriction;
TRUNCATE TABLE diet_recommendation.diet_recommendation;
TRUNCATE TABLE diet_recommendation.patient;
TRUNCATE TABLE diet_recommendation.metrics;
TRUNCATE TABLE diet_recommendation.exercises;
TRUNCATE TABLE diet_recommendation.diets;

-- 1) Ingestion brute MinIO → raw (mapping nominal)
INSERT INTO diet_recommendation.raw_diet
(patient_id_str, age, gender, weight_kg, height_cm, bmi, disease_type, severity,
 physical_activity_level, daily_caloric_intake, cholesterol_mg_dl, blood_pressure_mmhg,
 glucose_mg_dl, dietary_restrictions, allergies, preferred_cuisine, weekly_exercise_hours,
 adherence_to_diet_plan, dietary_nutrient_imbalance_score, diet_recommendation)
SELECT
    "Patient_ID"                       AS patient_id_str,
    "Age"                              AS age,
    "Gender"                           AS gender,
    "Weight_kg"                        AS weight_kg,
    "Height_cm"                        AS height_cm,
    "BMI"                              AS bmi,
    "Disease_Type"                     AS disease_type,
    "Severity"                         AS severity,
    "Physical_Activity_Level"          AS physical_activity_level,
    "Daily_Caloric_Intake"             AS daily_caloric_intake,
    "Cholesterol_mg/dL"                AS cholesterol_mg_dl,
    "Blood_Pressure_mmHg"              AS blood_pressure_mmhg,
    "Glucose_mg/dL"                    AS glucose_mg_dl,
    "Dietary_Restrictions"             AS dietary_restrictions,
    "Allergies"                        AS allergies,
    "Preferred_Cuisine"                AS preferred_cuisine,
    "Weekly_Exercise_Hours"            AS weekly_exercise_hours,
    "Adherence_to_Diet_Plan"           AS adherence_to_diet_plan,
    "Dietary_Nutrient_Imbalance_Score" AS dietary_nutrient_imbalance_score,
    "Diet_Recommendation"              AS diet_recommendation
FROM s3(
    minio_lake,
    filename = 'raw/external/diet_recommendation/_latest.csv',
    format   = 'CSVWithNames',
    structure = '"Patient_ID" String, "Age" UInt8, "Gender" String, "Weight_kg" Float32,
                 "Height_cm" UInt16, "BMI" Float32, "Disease_Type" String, "Severity" String,
                 "Physical_Activity_Level" String, "Daily_Caloric_Intake" UInt32,
                 "Cholesterol_mg/dL" Float32, "Blood_Pressure_mmHg" Float32, "Glucose_mg/dL" Float32,
                 "Dietary_Restrictions" String, "Allergies" String, "Preferred_Cuisine" String,
                 "Weekly_Exercise_Hours" Float32, "Adherence_to_Diet_Plan" Float32,
                 "Dietary_Nutrient_Imbalance_Score" Float32, "Diet_Recommendation" String'
)
SETTINGS
    input_format_allow_errors_num = 100,
    input_format_allow_errors_ratio = 0.1
;

-- 2) Dimensions
INSERT INTO diet_recommendation.disease (id, name, created_at, updated_at)
SELECT toUInt32(cityHash64(name) % 4294967295), name, now64(3), now64(3)
FROM (SELECT DISTINCT disease_type AS name FROM diet_recommendation.raw_diet WHERE disease_type NOT IN ('', 'None'));

INSERT INTO diet_recommendation.allergy (id, name, created_at, updated_at)
SELECT toUInt32(cityHash64(name) % 4294967295), name, now64(3), now64(3)
FROM (SELECT DISTINCT allergies AS name FROM diet_recommendation.raw_diet WHERE allergies NOT IN ('', 'None'));

INSERT INTO diet_recommendation.preferred_cuisine (id, name, created_at, updated_at)
SELECT toUInt32(cityHash64(name) % 4294967295), name, now64(3), now64(3)
FROM (SELECT DISTINCT preferred_cuisine AS name FROM diet_recommendation.raw_diet WHERE preferred_cuisine != '');

INSERT INTO diet_recommendation.dietary_restriction (id, name, created_at, updated_at)
SELECT toUInt32(cityHash64(name) % 4294967295), name, now64(3), now64(3)
FROM (SELECT DISTINCT dietary_restrictions AS name FROM diet_recommendation.raw_diet WHERE dietary_restrictions NOT IN ('', 'None'));

INSERT INTO diet_recommendation.diet_recommendation (id, name, created_at, updated_at)
SELECT toUInt32(cityHash64(name) % 4294967295), name, now64(3), now64(3)
FROM (SELECT DISTINCT diet_recommendation AS name FROM diet_recommendation.raw_diet WHERE diet_recommendation != '');

-- 3) Patient
INSERT INTO diet_recommendation.patient
SELECT
    toUInt32(cityHash64(patient_id_str) % 4294967295) AS id,
    patient_id_str AS id_data_set,
    age,
    gender,
    if(allergies IN ('', 'None'), [], [toUInt32(cityHash64(allergies) % 4294967295)]) AS allergy_ids,
    if(allergies IN ('', 'None'), [], [allergies]) AS allergy_names,
    if(disease_type IN ('', 'None'),
       '[]',
       concat('[{"id":', toString(toUInt32(cityHash64(disease_type) % 4294967295)),
              ',"severity":', if(severity IN ('', 'None'), 'null', concat('"', severity, '"')), '}]')
    ) AS diseases,
    now64(3), now64(3)
FROM diet_recommendation.raw_diet;

-- 4) Metrics et exercises
INSERT INTO diet_recommendation.metrics
SELECT
    toUInt32(cityHash64(patient_id_str, 'metrics') % 4294967295) AS id,
    toUInt32(cityHash64(patient_id_str) % 4294967295) AS patient_id,
    weight_kg, height_cm, bmi, cholesterol_mg_dl, blood_pressure_mmhg, glucose_mg_dl,
    now64(3), now64(3)
FROM diet_recommendation.raw_diet;

INSERT INTO diet_recommendation.exercises
SELECT
    toUInt32(cityHash64(patient_id_str, 'exercises') % 4294967295) AS id,
    toUInt32(cityHash64(patient_id_str) % 4294967295) AS patient_id,
    weekly_exercise_hours,
    physical_activity_level,
    now64(3), now64(3)
FROM diet_recommendation.raw_diet;

-- 5) Table de faits diets
INSERT INTO diet_recommendation.diets
SELECT
    toUInt32(cityHash64(patient_id_str, daily_caloric_intake, diet_recommendation) % 4294967295) AS id,
    daily_caloric_intake,
    adherence_to_diet_plan,
    dietary_nutrient_imbalance_score,
    toUInt32(cityHash64(patient_id_str) % 4294967295) AS patient_id,
    if(dietary_restrictions IN ('', 'None'), 0, toUInt32(cityHash64(dietary_restrictions) % 4294967295)) AS dietary_restriction_id,
    toUInt32(cityHash64(preferred_cuisine) % 4294967295) AS preferred_cuisine_id,
    toUInt32(cityHash64(diet_recommendation) % 4294967295) AS diet_recommendation_id,
    preferred_cuisine AS preferred_cuisine_name,
    if(dietary_restrictions IN ('', 'None'), '', dietary_restrictions) AS dietary_restriction_name,
    diet_recommendation AS diet_recommendation_name,
    age AS patient_age,
    gender AS patient_gender,
    now64(3), now64(3)
FROM diet_recommendation.raw_diet;
