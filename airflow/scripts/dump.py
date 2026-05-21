"""
Outil de dump et load pour healthbook data lake.

Dumps (lake/raw/api/) :
    docker compose run --rm dump-runner external      # datasets/ → lake/raw/external/
    docker compose run --rm dump-runner workout       # tracking-api → lake/raw/api/workout_session/
    docker compose run --rm dump-runner food          # recommendation-api/food-item
    docker compose run --rm dump-runner exercise      # recommendation-api/exercise
    docker compose run --rm dump-runner diet          # recommendation-api/diet
    docker compose run --rm dump-runner api           # tous les dumps API
    docker compose run --rm dump-runner all           # external + api

Loads (lake/raw/external/ → recommendation-api Postgres) :
    docker compose run --rm dump-runner load food_item
    docker compose run --rm dump-runner load exercise
    docker compose run --rm dump-runner load diet
    docker compose run --rm dump-runner load all
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
import psycopg
from minio import Minio
from minio.error import S3Error


# ────────────────────────────────────────────────────────────────
# Configuration
# ────────────────────────────────────────────────────────────────

MINIO_ENDPOINT = os.environ["MINIO_ENDPOINT"]
MINIO_ACCESS_KEY = os.environ["MINIO_ACCESS_KEY"]
MINIO_SECRET_KEY = os.environ["MINIO_SECRET_KEY"]
MINIO_BUCKET = os.environ["MINIO_BUCKET"]
TRACKING_API_URL = os.environ.get("TRACKING_API_URL", "http://tracking-api:3000")
RECOMMENDATION_API_URL = os.environ.get("RECOMMENDATION_API_URL", "http://recommendation-api:3000")
RECOMMENDATION_DB_URL = os.environ.get("RECOMMENDATION_DB_URL")

EXTERNAL_DIR = Path("/datasets")

EXTERNAL_DATASETS = {
    "daily_food":           ("daily_food_nutrition_dataset.csv", "csv"),
    "diet_recommendation":  ("diet_recommendations_dataset.csv", "csv"),
    "exercise":             ("exercises.json",                    "json"),
    "workout_session":      ("gym_members_exercise_tracking.csv", "csv"),
}

API_ENDPOINTS = {
    "workout_session":      f"{TRACKING_API_URL}/workout/export",
    "food_item":            f"{RECOMMENDATION_API_URL}/food-item/export",
    "exercise":             f"{RECOMMENDATION_API_URL}/exercise/export",
    "diet_recommendation":  f"{RECOMMENDATION_API_URL}/diet/export",
}

# ────────────────────────────────────────────────────────────────
# Mappings CSV header → nom canonique
# ────────────────────────────────────────────────────────────────

DAILY_FOOD_COLUMNS = {
    "Food_Item":              "food_item",
    "Category":               "category",
    "Calories (kcal)":        "calories",
    "Protein (g)":            "protein_g",
    "Carbohydrates (g)":      "carbohydrates_g",
    "Fat (g)":                "fat_g",
    "Fiber (g)":              "fiber_g",
    "Sugars (g)":             "sugars_g",
    "Sodium (mg)":            "sodium_mg",
    "Cholesterol (mg)":       "cholesterol_mg",
    "Meal_Type":              "meal_type",
    "Water_Intake (ml)":      "water_intake_ml",
}

DIET_COLUMNS = {
    "Patient_ID":                       "patient_id",
    "Age":                              "age",
    "Gender":                           "gender",
    "Weight_kg":                        "weight_kg",
    "Height_cm":                        "height_cm",
    "BMI":                              "bmi",
    "Disease_Type":                     "disease_type",
    "Severity":                         "severity",
    "Physical_Activity_Level":          "physical_activity_level",
    "Daily_Caloric_Intake":             "daily_caloric_intake",
    "Cholesterol_mg/dL":                "cholesterol_mg_dl",
    "Blood_Pressure_mmHg":              "blood_pressure_mmhg",
    "Glucose_mg/dL":                    "glucose_mg_dl",
    "Dietary_Restrictions":             "dietary_restrictions",
    "Allergies":                        "allergies",
    "Preferred_Cuisine":                "preferred_cuisine",
    "Weekly_Exercise_Hours":            "weekly_exercise_hours",
    "Adherence_to_Diet_Plan":           "adherence_to_diet_plan",
    "Dietary_Nutrient_Imbalance_Score": "dietary_nutrient_imbalance_score",
    "Diet_Recommendation":              "diet_recommendation",
}
# ────────────────────────────────────────────────────────────────
# Helpers communs
# ────────────────────────────────────────────────────────────────

def get_minio_client() -> Minio:
    endpoint = MINIO_ENDPOINT.replace("http://", "").replace("https://", "")
    secure = MINIO_ENDPOINT.startswith("https://")
    return Minio(endpoint, access_key=MINIO_ACCESS_KEY,
                 secret_key=MINIO_SECRET_KEY, secure=secure)


def now_utc_label() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")


def upload_bytes(client: Minio, key: str, data: bytes, content_type: str) -> None:
    client.put_object(
        bucket_name=MINIO_BUCKET,
        object_name=key,
        data=io.BytesIO(data),
        length=len(data),
        content_type=content_type,
    )
    print(f"  ✓ uploaded {key} ({len(data):,} bytes)")


def write_versioned(client: Minio, section: str, dataset: str,
                    payload: bytes, extension: str, content_type: str) -> str:
    label = now_utc_label()
    base = f"raw/{section}/{dataset}"
    upload_bytes(client, f"{base}/{label}/data.{extension}", payload, content_type)
    upload_bytes(client, f"{base}/_latest.{extension}", payload, content_type)
    return label


def download_latest(client: Minio, section: str, dataset: str, extension: str) -> bytes:
    """Télécharge le _latest.<ext> depuis le lake."""
    key = f"raw/{section}/{dataset}/_latest.{extension}"
    response = client.get_object(MINIO_BUCKET, key)
    try:
        return response.read()
    finally:
        response.close()
        response.release_conn()


# ────────────────────────────────────────────────────────────────
# Commandes DUMP
# ────────────────────────────────────────────────────────────────

def dump_external(client: Minio) -> None:
    print("→ Dumping external datasets")
    for dataset, (filename, extension) in EXTERNAL_DATASETS.items():
        local_path = EXTERNAL_DIR / filename
        if not local_path.exists():
            print(f"  ⚠ skip {dataset}: {local_path} not found")
            continue
        payload = local_path.read_bytes()
        content_type = "application/json" if extension == "json" else "text/csv"
        label = write_versioned(client, "external", dataset, payload, extension, content_type)
        print(f"  ✓ {dataset} → {label}/")


def dump_api(client: Minio, dataset: str, url: str) -> None:
    print(f"→ Dumping API {dataset} from {url}")
    try:
        with httpx.stream("GET", url, timeout=300.0) as response:
            response.raise_for_status()
            payload = response.read()
    except httpx.HTTPError as err:
        print(f"  ✗ FAILED {dataset}: {err}", file=sys.stderr)
        raise
    label = write_versioned(client, "api", dataset, payload, "csv", "text/csv")
    print(f"  ✓ {dataset} → {label}/  ({len(payload):,} bytes)")


def dump_all_api(client: Minio) -> None:
    for dataset, url in API_ENDPOINTS.items():
        dump_api(client, dataset, url)


# ────────────────────────────────────────────────────────────────
# Commandes LOAD : lake → Postgres recommendation-api
# ────────────────────────────────────────────────────────────────

def parse_csv(payload: bytes, column_map: dict[str, str] | None = None) -> list[dict[str, str | None]]:
    """Parse le CSV en liste de dicts. Applique optionnellement un mapping de colonnes."""
    reader = csv.DictReader(io.StringIO(payload.decode("utf-8")))
    rows = []
    for r in reader:
        if column_map:
            r = {column_map[k]: v for k, v in r.items() if k in column_map}
        # Normalise : '' / 'None' → None pour les champs nullables
        clean = {k: (v if v not in ("", "None") else None) for k, v in r.items()}
        rows.append(clean)
    return rows

def upsert_lookup(cur: psycopg.Cursor, table: str, name: str) -> int:
    """Upsert dans une dimension (name unique) et retourne l'id."""
    cur.execute(
        f"""
        INSERT INTO {table} (name, updated_at) VALUES (%s, now())
        ON CONFLICT (name) DO UPDATE SET updated_at = now()
        RETURNING id
        """,
        (name,),
    )
    return cur.fetchone()[0]


def load_food_item(client: Minio, conn: psycopg.Connection) -> None:
    print("→ Loading food_item from lake → Postgres")
    payload = download_latest(client, "external", "daily_food", "csv")
    rows = parse_csv(payload, DAILY_FOOD_COLUMNS)
    print(f"  read {len(rows)} CSV rows")

    with conn.cursor() as cur:
        # 1. Catégories : upsert et map name → id
        category_ids: dict[str, int] = {}
        for cat_name in {r["category"] for r in rows if r["category"]}:
            category_ids[cat_name] = upsert_lookup(cur, "daily_food_nutrition_food_category", cat_name)

        # 2. FoodItem : upsert par (name)
        for r in rows:
            cat_id = category_ids.get(r["category"])
            cur.execute(
                """
                INSERT INTO daily_food_nutrition_food_item
                    (name, meal_type, category_ids, calories, protein_g, carbohydrates_g,
                     fat_g, fiber_g, sugars_g, sodium_mg, cholesterol_mg, water_intake_ml, updated_at)
                VALUES (%s, %s::"MealType", %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now())
                ON CONFLICT (name) DO UPDATE SET
                    meal_type       = EXCLUDED.meal_type,
                    category_ids    = EXCLUDED.category_ids,
                    calories        = EXCLUDED.calories,
                    protein_g       = EXCLUDED.protein_g,
                    carbohydrates_g = EXCLUDED.carbohydrates_g,
                    fat_g           = EXCLUDED.fat_g,
                    fiber_g         = EXCLUDED.fiber_g,
                    sugars_g        = EXCLUDED.sugars_g,
                    sodium_mg       = EXCLUDED.sodium_mg,
                    cholesterol_mg  = EXCLUDED.cholesterol_mg,
                    water_intake_ml = EXCLUDED.water_intake_ml,
                    updated_at      = now()
                """,
                (
                    r["food_item"], r["meal_type"],
                    [cat_id] if cat_id else [],
                    int(r["calories"] or 0),
                    float(r["protein_g"] or 0), float(r["carbohydrates_g"] or 0),
                    float(r["fat_g"] or 0), float(r["fiber_g"] or 0),
                    float(r["sugars_g"] or 0),
                    int(r["sodium_mg"] or 0), int(r["cholesterol_mg"] or 0),
                    int(r["water_intake_ml"] or 0),
                ),
            )
    conn.commit()
    print(f"  ✓ loaded {len(rows)} food_items")


def load_exercise(client: Minio, conn: psycopg.Connection) -> None:
    print("→ Loading exercise from lake → Postgres")
    # Le dataset external est en JSON
    payload = download_latest(client, "external", "exercise", "json")
    items = json.loads(payload)
    print(f"  read {len(items)} JSON items")

    with conn.cursor() as cur:
        # 1. Dimensions : muscles, equipment, category
        muscle_ids: dict[str, int] = {}
        all_muscles = set()
        for item in items:
            for m in item.get("primaryMuscles", []) + item.get("secondaryMuscles", []):
                if m:
                    all_muscles.add(m)
        for m in all_muscles:
            muscle_ids[m] = upsert_lookup(cur, "exercise_db_muscle", m)

        equipment_ids: dict[str, int] = {}
        for eq in {item.get("equipment") for item in items if item.get("equipment")}:
            equipment_ids[eq] = upsert_lookup(cur, "exercise_db_equipment", eq)

        category_ids: dict[str, int] = {}
        for cat in {item.get("category") for item in items if item.get("category")}:
            category_ids[cat] = upsert_lookup(cur, "exercise_db_exercise_category", cat)

        # 2. ExerciseItem : upsert par (name)
        for item in items:
            primary_ids = [muscle_ids[m] for m in item.get("primaryMuscles", []) if m]
            secondary_ids = [muscle_ids[m] for m in item.get("secondaryMuscles", []) if m]
            cur.execute(
                """
                INSERT INTO exercise_db_exercise
                    (name, force, level, mechanic, instruction, photo,
                     primary_muscle_ids, secondary_muscle_ids, category_id, equipment_id, updated_at)
                VALUES (%s, %s::"Force", %s::"Level", %s::"Mechanic", %s, %s, %s, %s, %s, %s, now())
                ON CONFLICT (name) DO UPDATE SET
                    force                = EXCLUDED.force,
                    level                = EXCLUDED.level,
                    mechanic             = EXCLUDED.mechanic,
                    instruction          = EXCLUDED.instruction,
                    photo                = EXCLUDED.photo,
                    primary_muscle_ids   = EXCLUDED.primary_muscle_ids,
                    secondary_muscle_ids = EXCLUDED.secondary_muscle_ids,
                    category_id          = EXCLUDED.category_id,
                    equipment_id         = EXCLUDED.equipment_id,
                    updated_at           = now()
                """,
                (
                    item["name"],
                    item.get("force"),
                    item.get("level"),
                    item.get("mechanic"),
                    json.dumps(item.get("instructions", [])),
                    json.dumps(item.get("images", [])),
                    primary_ids,
                    secondary_ids,
                    category_ids.get(item.get("category")),
                    equipment_ids.get(item.get("equipment")),
                ),
            )
    conn.commit()
    print(f"  ✓ loaded {len(items)} exercises")


def load_diet(client: Minio, conn: psycopg.Connection) -> None:
    print("→ Loading diet from lake → Postgres")
    payload = download_latest(client, "external", "diet_recommendation", "csv")
    rows = parse_csv(payload, DIET_COLUMNS)
    print(f"  read {len(rows)} CSV rows")

    with conn.cursor() as cur:
        # 1. Dimensions
        disease_ids: dict[str, int] = {}
        for d in {r["disease_type"] for r in rows if r["disease_type"]}:
            disease_ids[d] = upsert_lookup(cur, "diet_recommendation_disease", d)

        allergy_ids: dict[str, int] = {}
        for a in {r["allergies"] for r in rows if r["allergies"]}:
            allergy_ids[a] = upsert_lookup(cur, "diet_recommendation_allergy", a)

        cuisine_ids: dict[str, int] = {}
        for c in {r["preferred_cuisine"] for r in rows if r["preferred_cuisine"]}:
            cuisine_ids[c] = upsert_lookup(cur, "diet_recommendation_preferred_cuisine", c)

        restriction_ids: dict[str, int] = {}
        for dr in {r["dietary_restrictions"] for r in rows if r["dietary_restrictions"]}:
            restriction_ids[dr] = upsert_lookup(cur, "diet_recommendation_dietary_restriction", dr)

        recommendation_ids: dict[str, int] = {}
        for dr in {r["diet_recommendation"] for r in rows if r["diet_recommendation"]}:
            recommendation_ids[dr] = upsert_lookup(cur, "diet_recommendation_diet_recommendation", dr)

        # 2. Patient + Metrics + Exercises + Diet (1 ligne CSV = 1 patient avec tout)
        for r in rows:
            patient_id_str = r["patient_id"]
            disease_payload = []
            if r["disease_type"]:
                disease_payload.append({
                    "id": disease_ids[r["disease_type"]],
                    "severity": r["severity"],
                })

            allergy_id_list = [allergy_ids[r["allergies"]]] if r["allergies"] else []

            # Patient (upsert par id_data_set)
            cur.execute(
                """
                INSERT INTO diet_recommendation_patient
                    (id_data_set, age, gender, allergy_ids, diseases, updated_at)
                VALUES (%s, %s, %s::"Gender", %s, %s::jsonb, now())
                ON CONFLICT (id_data_set) DO UPDATE SET
                    age          = EXCLUDED.age,
                    gender       = EXCLUDED.gender,
                    allergy_ids  = EXCLUDED.allergy_ids,
                    diseases     = EXCLUDED.diseases,
                    updated_at   = now()
                RETURNING id
                """,
                (
                    patient_id_str,
                    int(r["age"]),
                    r["gender"],
                    allergy_id_list,
                    json.dumps(disease_payload),
                ),
            )
            patient_id = cur.fetchone()[0]

            # Metrics : on append (1 patient peut avoir plusieurs snapshots)
            # Mais pour le seed, 1 metric par patient, donc on insère seulement si pas déjà fait
            cur.execute(
                """
                INSERT INTO diet_recommendation_metrics
                    (patient_id, weight_kg, height_cm, bmi, cholesterol_mg_dl,
                     blood_pressure_mmhg, glucose_mg_dl, updated_at)
                SELECT %s, %s, %s, %s, %s, %s, %s, now()
                WHERE NOT EXISTS (
                    SELECT 1 FROM diet_recommendation_metrics WHERE patient_id = %s
                )
                """,
                (
                    patient_id,
                    float(r["weight_kg"] or 0),
                    int(float(r["height_cm"] or 0)),
                    float(r["bmi"] or 0),
                    float(r["cholesterol_mg_dl"] or 0),
                    float(r["blood_pressure_mmhg"] or 0),
                    float(r["glucose_mg_dl"] or 0),
                    patient_id,
                ),
            )

            # PatientExercise : idem
            cur.execute(
                """
                INSERT INTO diet_recommendation_exercises
                    (patient_id, weekly_exercise_hours, physical_activity_level, updated_at)
                SELECT %s, %s, %s::"PhysicalActivityLevel", now()
                WHERE NOT EXISTS (
                    SELECT 1 FROM diet_recommendation_exercises WHERE patient_id = %s
                )
                """,
                (
                    patient_id,
                    float(r["weekly_exercise_hours"] or 0),
                    r["physical_activity_level"],
                    patient_id,
                ),
            )

            # Diet (upsert par patient_id, qui est unique)
            cur.execute(
                """
                INSERT INTO diet_recommendation_diets
                    (daily_caloric_intake, adherence_to_diet_plan, dietary_nutrient_imbalance_score,
                     patient_id, dietary_restriction_id, preferred_cuisine_id, diet_recommendation_id,
                     updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, now())
                ON CONFLICT (patient_id) DO UPDATE SET
                    daily_caloric_intake             = EXCLUDED.daily_caloric_intake,
                    adherence_to_diet_plan           = EXCLUDED.adherence_to_diet_plan,
                    dietary_nutrient_imbalance_score = EXCLUDED.dietary_nutrient_imbalance_score,
                    dietary_restriction_id           = EXCLUDED.dietary_restriction_id,
                    preferred_cuisine_id             = EXCLUDED.preferred_cuisine_id,
                    diet_recommendation_id           = EXCLUDED.diet_recommendation_id,
                    updated_at                       = now()
                """,
                (
                    int(r["daily_caloric_intake"] or 0),
                    float(r["adherence_to_diet_plan"] or 0),
                    float(r["dietary_nutrient_imbalance_score"] or 0),
                    patient_id,
                    restriction_ids.get(r["dietary_restrictions"]),
                    cuisine_ids[r["preferred_cuisine"]],
                    recommendation_ids[r["diet_recommendation"]],
                ),
            )

    conn.commit()
    print(f"  ✓ loaded {len(rows)} diet records")


def load_all(client: Minio, conn: psycopg.Connection) -> None:
    load_food_item(client, conn)
    load_exercise(client, conn)
    load_diet(client, conn)


# ────────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(description="Dump and load data for healthbook")
    sub = parser.add_subparsers(dest="command", required=True)

    # dump commands
    for cmd in ["external", "workout", "food", "exercise", "diet", "api", "all"]:
        sub.add_parser(cmd)

    # load command (avec sous-arg)
    load_parser = sub.add_parser("load")
    load_parser.add_argument("target", choices=["food_item", "exercise", "diet", "all"])

    args = parser.parse_args()

    client = get_minio_client()

    try:
        if not client.bucket_exists(MINIO_BUCKET):
            print(f"✗ Bucket {MINIO_BUCKET} does not exist", file=sys.stderr)
            return 1
    except S3Error as err:
        print(f"✗ MinIO error: {err}", file=sys.stderr)
        return 1

    if args.command == "external":
        dump_external(client)
    elif args.command == "workout":
        dump_api(client, "workout_session", API_ENDPOINTS["workout_session"])
    elif args.command == "food":
        dump_api(client, "food_item", API_ENDPOINTS["food_item"])
    elif args.command == "exercise":
        dump_api(client, "exercise", API_ENDPOINTS["exercise"])
    elif args.command == "diet":
        dump_api(client, "diet_recommendation", API_ENDPOINTS["diet_recommendation"])
    elif args.command == "api":
        dump_all_api(client)
    elif args.command == "all":
        dump_external(client)
        dump_all_api(client)
    elif args.command == "load":
        if not RECOMMENDATION_DB_URL:
            print("✗ RECOMMENDATION_DB_URL is not set", file=sys.stderr)
            return 1
        with psycopg.connect(RECOMMENDATION_DB_URL) as conn:
            if args.target == "food_item":
                load_food_item(client, conn)
            elif args.target == "exercise":
                load_exercise(client, conn)
            elif args.target == "diet":
                load_diet(client, conn)
            elif args.target == "all":
                load_all(client, conn)

    print("✓ done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
