-- 0) Reset
TRUNCATE TABLE daily_food.raw_food;
TRUNCATE TABLE daily_food.food_category;
TRUNCATE TABLE daily_food.food_item;

-- 1) Ingestion brute MinIO → raw (mapping nominal)
INSERT INTO daily_food.raw_food
(food_item, category, calories, protein_g, carbohydrates_g, fat_g, fiber_g,
 sugars_g, sodium_mg, cholesterol_mg, meal_type, water_intake_ml)
SELECT
    "Food_Item"          AS food_item,
    "Category"           AS category,
    "Calories (kcal)"    AS calories,
    "Protein (g)"        AS protein_g,
    "Carbohydrates (g)"  AS carbohydrates_g,
    "Fat (g)"            AS fat_g,
    "Fiber (g)"          AS fiber_g,
    "Sugars (g)"         AS sugars_g,
    "Sodium (mg)"        AS sodium_mg,
    "Cholesterol (mg)"   AS cholesterol_mg,
    "Meal_Type"          AS meal_type,
    "Water_Intake (ml)"  AS water_intake_ml
FROM s3(
    minio_lake,
    filename = 'raw/external/daily_food/_latest.csv',
    format   = 'CSVWithNames',
    structure = '"Food_Item" String, "Category" String, "Calories (kcal)" UInt32,
                 "Protein (g)" Float32, "Carbohydrates (g)" Float32, "Fat (g)" Float32,
                 "Fiber (g)" Float32, "Sugars (g)" Float32, "Sodium (mg)" UInt32,
                 "Cholesterol (mg)" UInt32, "Meal_Type" String, "Water_Intake (ml)" UInt32'
)
SETTINGS
    input_format_allow_errors_num = 100,
    input_format_allow_errors_ratio = 0.1
;

-- 2) Dimension food_category
INSERT INTO daily_food.food_category (id, name, created_at, updated_at)
SELECT
    toUInt32(cityHash64(name) % 4294967295) AS id,
    name,
    now64(3),
    now64(3)
FROM (SELECT DISTINCT category AS name FROM daily_food.raw_food WHERE category != '');

-- 3) Table principale food_item
INSERT INTO daily_food.food_item
SELECT
    toUInt32(cityHash64(food_item) % 4294967295) AS id,
    food_item AS name,
    meal_type,
    [toUInt32(cityHash64(category) % 4294967295)] AS category_ids,
    [category] AS category_names,
    calories, protein_g, carbohydrates_g, fat_g, fiber_g, sugars_g,
    sodium_mg, cholesterol_mg, water_intake_ml,
    now64(3), now64(3)
FROM daily_food.raw_food;
