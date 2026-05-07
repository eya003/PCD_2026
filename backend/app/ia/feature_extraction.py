from pathlib import Path

import nibabel as nib
import numpy as np
from scipy.stats import skew, kurtosis

def compute_volume_features(volumes: dict) -> dict:
    """
    Calcule les features dérivées à partir des volumes HippoDeep.
    """

    brain_volume = float(volumes["brain_volume_mm3"])
    hippo_l = float(volumes["hippo_L_mm3"])
    hippo_r = float(volumes["hippo_R_mm3"])
    hippo_total = hippo_l + hippo_r

    if brain_volume <= 0:
        raise ValueError("brain_volume_mm3 doit être supérieur à 0.")

    if hippo_total <= 0:
        raise ValueError("hippo_total_mm3 doit être supérieur à 0.")

    return {
        "hippo_L_mm3": hippo_l,
        "hippo_R_mm3": hippo_r,
        "hippo_total_mm3": hippo_total,
        "brain_volume_mm3": brain_volume,
        "hippo_L_over_brain": hippo_l / brain_volume,
        "hippo_R_over_brain": hippo_r / brain_volume,
        "hippo_total_over_brain": hippo_total / brain_volume,
        "hippo_asymmetry_abs": abs(hippo_l - hippo_r),
        "hippo_L_minus_R_over_total": (hippo_l - hippo_r) / hippo_total,
        "hippo_L_over_R": hippo_l / hippo_r if hippo_r != 0 else 0.0,
        "hippo_R_over_L": hippo_r / hippo_l if hippo_l != 0 else 0.0,
    }


def compute_roi_features(
    mri_path: Path,
    mask_l_path: Path,
    mask_r_path: Path,
) -> dict:
    """
    Calcule les features statistiques de la ROI hippocampique
    à partir de l'IRM et des masques gauche/droit générés par HippoDeep.
    """

    mri_path = Path(mri_path)
    mask_l_path = Path(mask_l_path)
    mask_r_path = Path(mask_r_path)

    if not mri_path.exists():
        raise FileNotFoundError(f"IRM introuvable : {mri_path}")

    if not mask_l_path.exists():
        raise FileNotFoundError(f"Masque gauche introuvable : {mask_l_path}")

    if not mask_r_path.exists():
        raise FileNotFoundError(f"Masque droit introuvable : {mask_r_path}")

    mri_img = nib.load(str(mri_path))
    mask_l_img = nib.load(str(mask_l_path))
    mask_r_img = nib.load(str(mask_r_path))

    mri_data = mri_img.get_fdata(dtype=np.float32)
    mask_l = mask_l_img.get_fdata(dtype=np.float32) > 0
    mask_r = mask_r_img.get_fdata(dtype=np.float32) > 0

    roi_mask = mask_l | mask_r

    if roi_mask.sum() == 0:
        raise ValueError("ROI hippocampique vide : les masques L/R ne contiennent aucun voxel.")

    roi_values = mri_data[roi_mask].astype(np.float32)

    roi_values = np.nan_to_num(roi_values)

    p01, p05, p10, p25, p75, p90, p95, p99 = np.percentile(
        roi_values,
        [1, 5, 10, 25, 75, 90, 95, 99],
    )

    roi_min = float(np.min(roi_values))
    roi_max = float(np.max(roi_values))

    return {
        "roi_mean": float(np.mean(roi_values)),
        "roi_std": float(np.std(roi_values)),
        "roi_median": float(np.median(roi_values)),
        "roi_min": roi_min,
        "roi_max": roi_max,
        "roi_p01": float(p01),
        "roi_p05": float(p05),
        "roi_p10": float(p10),
        "roi_p25": float(p25),
        "roi_p75": float(p75),
        "roi_p90": float(p90),
        "roi_p95": float(p95),
        "roi_p99": float(p99),
        "roi_iqr": float(p75 - p25),
        "roi_range": float(roi_max - roi_min),
        "roi_energy": float(np.sum(roi_values ** 2)),
        "roi_skew": float(skew(roi_values)),
        "roi_kurtosis": float(kurtosis(roi_values)),
    }