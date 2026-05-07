# backend/app/ia/hippodeep_runner.py

from pathlib import Path
import csv
import shutil
import subprocess
import sys
import uuid


BASE_DIR = Path(__file__).resolve().parent.parent
BACKEND_DIR = BASE_DIR.parent

HIPPODEEP_DIR = BASE_DIR / "third_party" / "hippodeep_pytorch"
HIPPODEEP_SCRIPT = HIPPODEEP_DIR / "hippodeep.py"

AI_WORK_DIR = BACKEND_DIR / "storage" / "ai_processing"


def run_hippodeep(input_mri_path: Path) -> dict:
    """
    Lance HippoDeep sur une IRM T1 .nii ou .nii.gz.

    Contrairement à l'ancienne version, cette fonction garde les fichiers générés
    dans backend/storage/ai_processing/.

    Retour :
    {
        "case_dir": "...",
        "input_mri_path": "...",
        "brain_volume_mm3": ...,
        "hippo_L_mm3": ...,
        "hippo_R_mm3": ...,
        "hippo_total_mm3": ...,
        "mask_L_path": "...",
        "mask_R_path": "...",
        "brain_mask_path": "...",
        "volumes_csv_path": "..."
    }
    """

    input_mri_path = Path(input_mri_path)

    if not input_mri_path.exists():
        raise FileNotFoundError(f"IRM introuvable : {input_mri_path}")

    if not HIPPODEEP_SCRIPT.exists():
        raise FileNotFoundError(f"Script HippoDeep introuvable : {HIPPODEEP_SCRIPT}")

    AI_WORK_DIR.mkdir(parents=True, exist_ok=True)

    case_id = f"case_{uuid.uuid4().hex}"
    case_dir = AI_WORK_DIR / case_id
    case_dir.mkdir(parents=True, exist_ok=True)

    local_input_path = case_dir / input_mri_path.name
    shutil.copy2(input_mri_path, local_input_path)

    command = [
        sys.executable,
        str(HIPPODEEP_SCRIPT),
        str(local_input_path),
    ]

    result = subprocess.run(
        command,
        cwd=str(HIPPODEEP_DIR),
        capture_output=True,
        text=True,
        timeout=300,
    )

    stdout_path = case_dir / "hippodeep_stdout.txt"
    stderr_path = case_dir / "hippodeep_stderr.txt"

    stdout_path.write_text(result.stdout, encoding="utf-8")
    stderr_path.write_text(result.stderr, encoding="utf-8")

    if result.returncode != 0:
        raise RuntimeError(
            "HippoDeep failed.\n"
            f"STDOUT:\n{result.stdout}\n"
            f"STDERR:\n{result.stderr}"
        )

    # HippoDeep écrit les sorties à côté de l'input local.
    mask_l_path = _find_file(case_dir, "*_mask_L.nii*")
    mask_r_path = _find_file(case_dir, "*_mask_R.nii*")
    brain_mask_path = _find_file(case_dir, "*_brain_mask.nii*")
    volumes_csv_path = _find_file(case_dir, "*_hippoLR_volumes.csv")

    if mask_l_path is None:
        raise FileNotFoundError("Masque hippocampe gauche introuvable après HippoDeep.")

    if mask_r_path is None:
        raise FileNotFoundError("Masque hippocampe droit introuvable après HippoDeep.")

    if volumes_csv_path is None:
        raise FileNotFoundError("CSV volumes HippoDeep introuvable après HippoDeep.")

    volumes = _read_hippodeep_volumes(volumes_csv_path)

    return {
        "case_dir": str(case_dir),
        "input_mri_path": str(local_input_path),
        "brain_volume_mm3": volumes["brain_volume_mm3"],
        "hippo_L_mm3": volumes["hippo_L_mm3"],
        "hippo_R_mm3": volumes["hippo_R_mm3"],
        "hippo_total_mm3": volumes["hippo_total_mm3"],
        "mask_L_path": str(mask_l_path),
        "mask_R_path": str(mask_r_path),
        "brain_mask_path": str(brain_mask_path) if brain_mask_path else None,
        "volumes_csv_path": str(volumes_csv_path),
    }


def _find_file(folder: Path, pattern: str) -> Path | None:
    """
    Cherche un fichier généré par HippoDeep.
    """

    matches = list(folder.glob(pattern))

    if not matches:
        return None

    return matches[0]


def _read_hippodeep_volumes(csv_path: Path) -> dict:
    """
    Lit le CSV généré par HippoDeep.

    Exemple :
    eTIV,hippoL,hippoR
    1439994,3161,3344
    """

    with open(csv_path, "r", encoding="utf-8") as file:
        reader = csv.DictReader(file)
        row = next(reader, None)

    if row is None:
        raise ValueError(f"CSV HippoDeep vide : {csv_path}")

    brain_volume = float(row["eTIV"])
    hippo_l = float(row["hippoL"])
    hippo_r = float(row["hippoR"])

    return {
        "brain_volume_mm3": brain_volume,
        "hippo_L_mm3": hippo_l,
        "hippo_R_mm3": hippo_r,
        "hippo_total_mm3": hippo_l + hippo_r,
    }