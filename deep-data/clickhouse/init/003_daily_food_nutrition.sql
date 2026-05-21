CREATE TABLE IF NOT EXISTS daily_food.food_category (
    id UInt32, name String, created_at DateTime64(3), updated_at DateTime64(3)
) ENGINE = ReplacingMergeTree(updated_at) ORDER BY id;

CREATE TABLE IF NOT EXISTS daily_food.food_item (
    id              UInt32,
    name            String,
    meal_type       LowCardinality(String),
    category_ids    Array(UInt32),
    category_names  Array(String),
    calories        UInt32,
    protein_g       Float32,
    carbohydrates_g Float32,
    fat_g           Float32,
    fiber_g         Float32,
    sugars_g        Float32,
    sodium_mg       UInt32,
    cholesterol_mg  UInt32,
    water_intake_ml UInt32,
    created_at      DateTime64(3),
    updated_at      DateTime64(3)
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (meal_type, calories, id);
