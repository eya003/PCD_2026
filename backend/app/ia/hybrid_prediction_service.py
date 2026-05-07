# backend/app/ia/hybrid_prediction_service.py

from pathlib import Path

from .cnn_predictor import predict_cnn_from_paths
from .feature_extraction import compute_roi_features, compute_volume_features
from .hippodeep_runner import run_hippodeep
from .prediction_service import predict_from_features


def predict_alzheimer_from_mri(input_mri_path: Path) -> dict:
    """
    Pipeline IA complet à partir d'une IRM NIfTI.

    Étapes :
    1. Lance HippoDeep
    2. Calcule les features ROI
    3. Calcule les features volumes
    4. Lance le CNN
    5. Lance le modèle ML final .joblib
    """

    input_mri_path = Path(input_mri_path)

    if not input_mri_path.exists():
        raise FileNotFoundError(f"IRM introuvable : {input_mri_path}")

    # 1. HippoDeep
    hippo_result = run_hippodeep(input_mri_path)

    processed_mri_path = Path(hippo_result["input_mri_path"])
    mask_l_path = Path(hippo_result["mask_L_path"])
    mask_r_path = Path(hippo_result["mask_R_path"])

    # 2. Features ROI
    roi_features = compute_roi_features(
        mri_path=processed_mri_path,
        mask_l_path=mask_l_path,
        mask_r_path=mask_r_path,
    )

    # 3. Features volumes
    volume_features = compute_volume_features(
        {
            "brain_volume_mm3": hippo_result["brain_volume_mm3"],
            "hippo_L_mm3": hippo_result["hippo_L_mm3"],
            "hippo_R_mm3": hippo_result["hippo_R_mm3"],
            "hippo_total_mm3": hippo_result["hippo_total_mm3"],
        }
    )

    # 4. CNN
    cnn_features = predict_cnn_from_paths(
        mri_path=processed_mri_path,
        mask_l_path=mask_l_path,
        mask_r_path=mask_r_path,
        debug=False,
    )

    # 5. Fusion des features
    all_features = {}
    all_features.update(roi_features)
    all_features.update(volume_features)
    all_features.update(
        {
            "cnn_prob_AD": cnn_features["cnn_prob_AD"],
            "cnn_pred_061": cnn_features["cnn_pred_061"],
        }
    )

    # 6. Modèle final .joblib
    final_prediction = predict_from_features(all_features)

    return {
        "predicted_class": final_prediction["predicted_class"],
        "confidence_score": final_prediction["confidence_score"],
        "prob_ad": final_prediction["prob_ad"],
        "threshold": final_prediction["threshold"],
        "cnn_prob_AD": cnn_features["cnn_prob_AD"],
        "cnn_pred_061": cnn_features["cnn_pred_061"],
        "case_dir": hippo_result["case_dir"],
        "input_mri_path": hippo_result["input_mri_path"],
        "mask_L_path": hippo_result["mask_L_path"],
        "mask_R_path": hippo_result["mask_R_path"],
        "brain_mask_path": hippo_result["brain_mask_path"],
        "volumes_csv_path": hippo_result["volumes_csv_path"],
        "features": all_features,
    }