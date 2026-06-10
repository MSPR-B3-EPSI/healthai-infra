-- 0) Reset
TRUNCATE TABLE exercise_db.raw_exercise;
TRUNCATE TABLE exercise_db.muscle;
TRUNCATE TABLE exercise_db.equipment;
TRUNCATE TABLE exercise_db.exercise_category;
TRUNCATE TABLE exercise_db.exercise;

-- 1) Ingestion brute MinIO → raw (mapping nominal)
--    Le JSON est un tableau d'objets ; CSVWithNames-équivalent côté JSON = JSONEachRow.
--    Les champs `force`, `mechanic`, `equipment` peuvent être null dans le source
--    → on les déclare Nullable(String) puis on les normalise en '' à l'INSERT.
INSERT INTO exercise_db.raw_exercise
(id_str, name, force, level, mechanic, equipment, category,
 primary_muscles, secondary_muscles, instructions, images)
SELECT
    id                              AS id_str,
    name,
    ifNull(force, '')               AS force,
    level,
    ifNull(mechanic, '')            AS mechanic,
    ifNull(equipment, '')           AS equipment,
    category,
    primaryMuscles                  AS primary_muscles,
    secondaryMuscles                AS secondary_muscles,
    instructions,
    images
FROM s3(
    minio_lake,
    filename = 'raw/external/exercise/_latest.json',
    format   = 'JSONEachRow',
    structure = 'id String, name String,
                 force Nullable(String), level String, mechanic Nullable(String),
                 equipment Nullable(String), category String,
                 primaryMuscles Array(String), secondaryMuscles Array(String),
                 instructions Array(String), images Array(String)'
)
SETTINGS
    input_format_allow_errors_num = 100,
    input_format_allow_errors_ratio = 0.1
;

-- 2) Dimension muscle : union des primary + secondary muscles distincts
INSERT INTO exercise_db.muscle (id, name, created_at, updated_at)
SELECT
    toUInt32(cityHash64(name) % 4294967295) AS id,
    name,
    now64(3),
    now64(3)
FROM (
    SELECT DISTINCT arrayJoin(primary_muscles) AS name
    FROM exercise_db.raw_exercise WHERE length(primary_muscles) > 0
    UNION DISTINCT
    SELECT DISTINCT arrayJoin(secondary_muscles) AS name
    FROM exercise_db.raw_exercise WHERE length(secondary_muscles) > 0
)
WHERE name != '';

-- 3) Dimension equipment
INSERT INTO exercise_db.equipment (id, name, created_at, updated_at)
SELECT
    toUInt32(cityHash64(name) % 4294967295) AS id,
    name,
    now64(3),
    now64(3)
FROM (SELECT DISTINCT equipment AS name FROM exercise_db.raw_exercise WHERE equipment != '');

-- 4) Dimension exercise_category
INSERT INTO exercise_db.exercise_category (id, name, created_at, updated_at)
SELECT
    toUInt32(cityHash64(name) % 4294967295) AS id,
    name,
    now64(3),
    now64(3)
FROM (SELECT DISTINCT category AS name FROM exercise_db.raw_exercise WHERE category != '');

-- 5) Table principale exercise (dénormalisée — colonnes _name aplaties à côté des _id)
INSERT INTO exercise_db.exercise
SELECT
    id_str                                                                   AS id,
    name,
    force,
    level,
    mechanic,
    toJSONString(instructions)                                               AS instruction,
    toJSONString(images)                                                     AS photo,
    arrayMap(m -> toUInt32(cityHash64(m) % 4294967295), primary_muscles)     AS primary_muscle_ids,
    arrayMap(m -> toUInt32(cityHash64(m) % 4294967295), secondary_muscles)   AS secondary_muscle_ids,
    toUInt32(cityHash64(category) % 4294967295)                              AS category_id,
    if(equipment = '', 0, toUInt32(cityHash64(equipment) % 4294967295))      AS equipment_id,
    category                                                                 AS category_name,
    equipment                                                                AS equipment_name,
    primary_muscles                                                          AS primary_muscle_names,
    now64(3),
    now64(3)
FROM exercise_db.raw_exercise;
