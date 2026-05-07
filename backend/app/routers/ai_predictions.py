# backend/app/routers/ai_predictions.py

import json
import shutil
import tempfile
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_current_user, get_db
from ..ia.hybrid_prediction_service import predict_alzheimer_from_mri
from ..ia.prediction_service import predict_from_features


router = APIRouter()


class AIPredictFeaturesRequest(BaseModel):
    """
    Requête envoyée au backend pour lancer une prédiction IA.

    Important :
    - Pour l’instant, on n’envoie pas une IRM brute.
    - On envoie les features numériques déjà calculées.
    """

    patient_id: int = Field(gt=0)
    questionnaire_id: int | None = Field(default=None, gt=0)
    features: dict[str, float]

    model_config = ConfigDict(extra="forbid")


class AIPredictFeaturesResponse(BaseModel):
    """
    Réponse retournée après prédiction IA à partir des features numériques.
    """

    diagnosis_id: int
    patient_id: int
    questionnaire_id: int | None = None
    predicted_class: str
    confidence_score: float
    prob_ad: float
    threshold: float
    message: str


class AIPredictMRIResponse(BaseModel):
    """
    Réponse retournée après prédiction IA complète à partir d'une IRM.
    """

    diagnosis_id: int
    patient_id: int
    questionnaire_id: int | None = None
    predicted_class: str
    confidence_score: float
    prob_ad: float
    cnn_prob_AD: float | None = None
    cnn_pred_061: float | None = None
    threshold: float
    message: str


@router.post(
    "/predict-features",
    response_model=AIPredictFeaturesResponse,
    status_code=status.HTTP_201_CREATED,
)
def predict_features(
    payload: AIPredictFeaturesRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Lance une prédiction IA à partir des features numériques,
    puis sauvegarde automatiquement le résultat dans la table diagnoses.
    """

    # 1. Vérifier que l'utilisateur est médecin
    if current_user.role != "doctor":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only doctors can launch AI prediction",
        )

    # 2. Vérifier que le patient existe
    patient = cruds.get_patient(db, payload.patient_id)

    if patient is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found",
        )

    # 3. Vérifier le questionnaire si fourni
    questionnaire_score = None

    if payload.questionnaire_id is not None:
        questionnaire = cruds.get_questionnaire(db, payload.questionnaire_id)

        if questionnaire is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Questionnaire not found",
            )

        if questionnaire.patient_id != payload.patient_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Questionnaire does not belong to this patient",
            )

        questionnaire_score = questionnaire.score

    # 4. Prédiction IA
    try:
        prediction = predict_from_features(payload.features)

    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc

    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI prediction failed: {str(exc)}",
        ) from exc

    # 5. Sauvegarde dans diagnoses
    diagnosis_payload = schemas.DiagnosisCreate(
        patient_id=payload.patient_id,
        doctor_id=current_user.id,
        questionnaire_id=payload.questionnaire_id,
        model_result=prediction["predicted_class"],
        confidence_score=prediction["confidence_score"],
        questionnaire_score=questionnaire_score,
        final_medical_opinion=None,
    )

    try:
        diagnosis = cruds.create_diagnosis(
            db=db,
            payload=diagnosis_payload,
        )

    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Diagnosis conflict",
        ) from None

    return AIPredictFeaturesResponse(
        diagnosis_id=diagnosis.id,
        patient_id=diagnosis.patient_id,
        questionnaire_id=diagnosis.questionnaire_id,
        predicted_class=prediction["predicted_class"],
        confidence_score=prediction["confidence_score"],
        prob_ad=prediction["prob_ad"],
        threshold=prediction["threshold"],
        message="AI prediction saved successfully",
    )


@router.post(
    "/predict-mri",
    response_model=AIPredictMRIResponse,
    status_code=status.HTTP_201_CREATED,
)
def predict_mri(
    patient_id: int = Form(...),
    questionnaire_id: int | None = Form(None),
    mri_file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Lance une prédiction IA complète à partir d'une IRM NIfTI.

    Pipeline :
    IRM .nii / .nii.gz
    -> HippoDeep
    -> extraction des volumes/features
    -> CNN ResNet34 3D
    -> modèle final BernoulliNB
    -> sauvegarde automatique dans la table diagnoses.
    """

    # 1. Vérifier que l'utilisateur est médecin
    if current_user.role != "doctor":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only doctors can launch MRI AI prediction",
        )

    # 2. Vérifier que le patient existe
    patient = cruds.get_patient(db, patient_id)

    if patient is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found",
        )

    # 3. Vérifier le questionnaire si fourni
    questionnaire_score = None

    if questionnaire_id is not None:
        questionnaire = cruds.get_questionnaire(db, questionnaire_id)

        if questionnaire is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Questionnaire not found",
            )

        if questionnaire.patient_id != patient_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Questionnaire does not belong to this patient",
            )

        questionnaire_score = questionnaire.score

    # 4. Vérifier le fichier IRM uploadé
    original_filename = mri_file.filename or ""

    if not (
        original_filename.endswith(".nii")
        or original_filename.endswith(".nii.gz")
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid MRI file format. Expected .nii or .nii.gz",
        )

    suffix = ".nii.gz" if original_filename.endswith(".nii.gz") else ".nii"

    # 5. Sauvegarder temporairement le fichier IRM
    temp_dir = tempfile.TemporaryDirectory()

    try:
        temp_mri_path = Path(temp_dir.name) / f"uploaded_mri{suffix}"

        with temp_mri_path.open("wb") as buffer:
            shutil.copyfileobj(mri_file.file, buffer)

        # 6. Lancer le pipeline IA complet
        prediction = predict_alzheimer_from_mri(temp_mri_path)

    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc

    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"MRI AI prediction failed: {str(exc)}",
        ) from exc

    finally:
        temp_dir.cleanup()
        mri_file.file.close()

    # 7. Vérifier que le résultat IA contient les champs nécessaires
    required_keys = [
        "predicted_class",
        "confidence_score",
        "prob_ad",
        "threshold",
    ]

    for key in required_keys:
        if key not in prediction:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Missing key in MRI prediction result: {key}",
            )

    predicted_class = prediction["predicted_class"]
    confidence_score = float(prediction["confidence_score"])
    prob_ad = float(prediction["prob_ad"])
    threshold = float(prediction["threshold"])

    cnn_prob_AD = prediction.get("cnn_prob_AD")
    cnn_pred_061 = prediction.get("cnn_pred_061")

    if cnn_prob_AD is not None:
        cnn_prob_AD = float(cnn_prob_AD)

    if cnn_pred_061 is not None:
        cnn_pred_061 = float(cnn_pred_061)

    # 8. Préparer les détails IA à garder dans final_medical_opinion
    #
    # Important :
    # La table diagnoses ne contient pas directement :
    # - prob_ad
    # - cnn_prob_AD
    # - cnn_pred_061
    # - threshold
    #
    # Donc on garde ces détails sous forme JSON dans final_medical_opinion.
    ai_details = {
        "source": "predict-mri",
        "mri_filename": original_filename,
        "predicted_class": predicted_class,
        "confidence_score": confidence_score,
        "prob_ad": prob_ad,
        "cnn_prob_AD": cnn_prob_AD,
        "cnn_pred_061": cnn_pred_061,
        "threshold": threshold,
    }

    # 9. Sauvegarder dans diagnoses
    diagnosis_payload = schemas.DiagnosisCreate(
        patient_id=patient_id,
        doctor_id=current_user.id,
        questionnaire_id=questionnaire_id,
        model_result=predicted_class,
        confidence_score=confidence_score,
        questionnaire_score=questionnaire_score,
        final_medical_opinion=json.dumps(ai_details, ensure_ascii=False),
    )

    try:
        diagnosis = cruds.create_diagnosis(
            db=db,
            payload=diagnosis_payload,
        )

    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Diagnosis conflict",
        ) from None

    # 10. Retourner la réponse Swagger/API
    return AIPredictMRIResponse(
        diagnosis_id=diagnosis.id,
        patient_id=diagnosis.patient_id,
        questionnaire_id=diagnosis.questionnaire_id,
        predicted_class=predicted_class,
        confidence_score=confidence_score,
        prob_ad=prob_ad,
        cnn_prob_AD=cnn_prob_AD,
        cnn_pred_061=cnn_pred_061,
        threshold=threshold,
        message="MRI AI prediction saved successfully",
    )