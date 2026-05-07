# backend/app/ia/cnn_predictor.py

from functools import lru_cache
from pathlib import Path

import nibabel as nib
import numpy as np
import torch
from scipy.ndimage import zoom

from .cnn_model import build_resnet34_3d


BASE_DIR = Path(__file__).resolve().parent.parent

CNN_MODEL_PATH = (
    BASE_DIR
    / "ml_models"
    / "final_hybrid_model"
    / "cnn"
    / "best_resnet34_seed42_threshold061.pth"
)

CNN_THRESHOLD = 0.61
CNN_INPUT_SHAPE = (64, 64, 64)
ROI_MARGIN = 8


@lru_cache(maxsize=1)
def get_cnn_model():
    """
    Charge le CNN ResNet34 3D une seule fois.
    """

    if not CNN_MODEL_PATH.exists():
        raise FileNotFoundError(f"Modèle CNN introuvable : {CNN_MODEL_PATH}")

    checkpoint = torch.load(
        CNN_MODEL_PATH,
        map_location="cpu",
    )

    model = build_resnet34_3d()
    model.load_state_dict(
        checkpoint["model_state_dict"],
        strict=True,
    )
    model.eval()

    return model


def prepare_roi_volume(
    mri_path: Path,
    mask_l_path: Path,
    mask_r_path: Path,
) -> torch.Tensor:
    """
    Prépare la ROI hippocampique pour le CNN.

    Logique adaptée du pipeline envoyé par Eya :
    - on utilise les masques uniquement pour trouver la bounding box ;
    - on croppe l'image IRM brute autour de l'hippocampe ;
    - on resize en 64x64x64 ;
    - on normalise le volume ;
    - sortie PyTorch : (1, 1, D, H, W).
    """

    roi = build_roi_array(
        mri_path=mri_path,
        mask_l_path=mask_l_path,
        mask_r_path=mask_r_path,
    )

    roi = normalize_volume(roi)

    tensor = torch.tensor(roi, dtype=torch.float32)

    # Shape : (D, H, W) -> (B, C, D, H, W)
    tensor = tensor.unsqueeze(0).unsqueeze(0)

    return tensor


def build_roi_array(
    mri_path: Path,
    mask_l_path: Path,
    mask_r_path: Path,
) -> np.ndarray:
    """
    Crée une ROI 3D 64x64x64 à partir de l'IRM et des masques.
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

    volume = load_nifti_data(mri_path)
    mask_l = load_nifti_data(mask_l_path)
    mask_r = load_nifti_data(mask_r_path)

    mask = (mask_l > 0) | (mask_r > 0)
    coords = np.argwhere(mask)

    if coords.shape[0] == 0:
        raise ValueError("Masque hippocampe vide.")

    mins = coords.min(axis=0)
    maxs = coords.max(axis=0) + 1

    mins = np.maximum(mins - ROI_MARGIN, 0)
    maxs = np.minimum(maxs + ROI_MARGIN, volume.shape)

    crop = volume[
        mins[0] : maxs[0],
        mins[1] : maxs[1],
        mins[2] : maxs[2],
    ]

    roi = resize_3d(crop, CNN_INPUT_SHAPE)
    roi = np.nan_to_num(roi).astype(np.float32)

    return roi


def load_nifti_data(path: Path) -> np.ndarray:
    img = nib.load(str(path))
    data = img.get_fdata().astype(np.float32)
    return np.nan_to_num(data)


def resize_3d(
    volume: np.ndarray,
    target_shape: tuple[int, int, int],
) -> np.ndarray:
    """
    Resize 3D avec interpolation linéaire.
    """

    factors = [
        target_shape[0] / volume.shape[0],
        target_shape[1] / volume.shape[1],
        target_shape[2] / volume.shape[2],
    ]

    resized = zoom(volume, factors, order=1)

    out = np.zeros(target_shape, dtype=np.float32)

    min_x = min(target_shape[0], resized.shape[0])
    min_y = min(target_shape[1], resized.shape[1])
    min_z = min(target_shape[2], resized.shape[2])

    out[:min_x, :min_y, :min_z] = resized[:min_x, :min_y, :min_z]

    return out


def normalize_volume(volume: np.ndarray) -> np.ndarray:
    """
    Normalisation utilisée avant l'inférence CNN.
    """

    volume = np.nan_to_num(volume).astype(np.float32)

    mean = float(volume.mean())
    std = float(volume.std())

    if std < 1e-8:
        return np.zeros_like(volume, dtype=np.float32)

    return ((volume - mean) / std).astype(np.float32)


def predict_cnn_from_paths(
    mri_path: Path,
    mask_l_path: Path,
    mask_r_path: Path,
    debug: bool = False,
) -> dict:
    """
    Calcule cnn_prob_AD et cnn_pred_061 à partir de l'IRM + masques.
    """

    model = get_cnn_model()

    input_tensor = prepare_roi_volume(
        mri_path=mri_path,
        mask_l_path=mask_l_path,
        mask_r_path=mask_r_path,
    )

    with torch.no_grad():
        output = model(input_tensor)
        raw_output = output.view(-1)[0].item()
        prob_ad = torch.sigmoid(output.view(-1))[0].item()

    if debug:
        print("CNN raw_output =", raw_output)
        print("CNN prob_ad =", prob_ad)
        print("CNN input shape =", tuple(input_tensor.shape))
        print("CNN input min/max =", float(input_tensor.min()), float(input_tensor.max()))

    pred = 1 if prob_ad >= CNN_THRESHOLD else 0

    return {
        "cnn_prob_AD": round(float(prob_ad), 6),
        "cnn_pred_061": float(pred),
        "cnn_raw_output": round(float(raw_output), 6),
    }