from functools import lru_cache
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_PATH = BASE_DIR / "alzcare_model" / "bernoulliNB_features_cnn_model.joblib"


@lru_cache(maxsize=1)
def get_ai_model():
    """Load the AI model once and reuse it for later predictions."""
    if not MODEL_PATH.exists():
        raise FileNotFoundError(f"Modele IA introuvable : {MODEL_PATH}")

    import joblib

    return joblib.load(MODEL_PATH)
