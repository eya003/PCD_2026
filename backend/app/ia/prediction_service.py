# backend/app/ia/prediction_service.py

import pandas as pd

from .feature_columns import FEATURE_COLUMNS
from .model_loader import get_ai_model


BEST_THRESHOLD = 0.1


def validate_features(features: dict) -> dict:
    """
    Vérifie que toutes les features nécessaires sont présentes
    et les remet dans le bon ordre.
    """

    missing_features = [
        column for column in FEATURE_COLUMNS
        if column not in features
    ]

    if missing_features:
        raise ValueError(f"Features manquantes : {missing_features}")

    cleaned_features = {}

    for column in FEATURE_COLUMNS:
        value = features[column]

        if value is None:
            raise ValueError(f"La feature '{column}' est vide.")

        try:
            cleaned_features[column] = float(value)
        except (TypeError, ValueError):
            raise ValueError(
                f"La feature '{column}' doit etre numerique. Valeur recue : {value}"
            ) from None

    return cleaned_features


def predict_from_features(features: dict) -> dict:
    """
    Prédit AD/CN à partir des features numériques pré-calculées.
    """

    cleaned_features = validate_features(features)

    input_df = pd.DataFrame(
        [cleaned_features],
        columns=FEATURE_COLUMNS,
    )

    # Le pipeline sklearn a été entraîné sans noms de colonnes.
    # On convertit donc en numpy pour éviter le warning :
    # "X has feature names, but StandardScaler was fitted without feature names".
    model_input = input_df.to_numpy(dtype=float)

    model = get_ai_model()

    if hasattr(model, "predict_proba"):
        probabilities = model.predict_proba(model_input)[0]

        if hasattr(model, "classes_"):
            classes = list(model.classes_)

            if 1 in classes:
                ad_index = classes.index(1)
            elif "AD" in classes:
                ad_index = classes.index("AD")
            else:
                ad_index = 1
        else:
            ad_index = 1

        prob_ad = float(probabilities[ad_index])

    else:
        prediction = model.predict(model_input)[0]
        prob_ad = 1.0 if prediction in [1, "AD"] else 0.0

    predicted_class = "AD" if prob_ad >= BEST_THRESHOLD else "CN"
    confidence_score = prob_ad if predicted_class == "AD" else 1.0 - prob_ad

    return {
        "predicted_class": predicted_class,
        "confidence_score": round(confidence_score, 6),
        "prob_ad": round(prob_ad, 6),
        "threshold": BEST_THRESHOLD,
    }