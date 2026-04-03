from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_current_user, get_db

router = APIRouter()


@router.post("/link-patient", response_model=schemas.FamilyPatientLink, status_code=201)
def link_family_to_patient(
    payload: schemas.FamilyPatientLinkCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role not in {"doctor", "family"}:
        raise HTTPException(status_code=403, detail="Not allowed")

    family_user = cruds.get_user(db, payload.user_id)
    if family_user is None or family_user.role != "family":
        raise HTTPException(status_code=404, detail="Family user not found")

    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    existing_link = cruds.get_family_patient_link(
        db, user_id=payload.user_id, patient_id=payload.patient_id
    )
    if existing_link:
        raise HTTPException(status_code=400, detail="Family member already linked")

    if payload.family_role == "admin":
        existing_admin = cruds.get_family_admin_link(db, payload.patient_id)
        if existing_admin is not None:
            raise HTTPException(
                status_code=409,
                detail="An admin already exists for this patient",
            )

    try:
        return cruds.link_family_to_patient(
            db=db,
            user_id=payload.user_id,
            patient_id=payload.patient_id,
            family_role=payload.family_role,
            relation_to_patient=payload.relation_to_patient,
        )
    except cruds.AdminConflictError:
        raise HTTPException(
            status_code=409,
            detail="An admin already exists for this patient",
        ) from None
    except cruds.RoleConstraintError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from None
    except cruds.BusinessRuleError as exc:
        status_code = 404 if str(exc) == "Patient not found" else 400
        raise HTTPException(status_code=status_code, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Unable to link family member") from None


@router.post("/transfer-admin", response_model=schemas.FamilyPatientLink)
def transfer_family_admin(
    payload: schemas.TransferFamilyAdminRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    target_user = cruds.get_user(db, payload.new_admin_user_id)
    if target_user is None or target_user.role != "family":
        raise HTTPException(status_code=404, detail="Target family user not found")

    if current_user.role != "doctor":
        requester_link = cruds.get_family_patient_link(db, current_user.id, payload.patient_id)
        if requester_link is None or requester_link.family_role != "admin":
            raise HTTPException(status_code=403, detail="Only family admin can transfer admin")

    target_link = cruds.get_family_patient_link(db, payload.new_admin_user_id, payload.patient_id)
    if target_link is None:
        raise HTTPException(status_code=404, detail="Target user is not linked to this patient")

    try:
        updated_link = cruds.transfer_family_admin(
            db=db,
            patient_id=payload.patient_id,
            new_admin_user_id=payload.new_admin_user_id,
        )
    except IntegrityError:
        raise HTTPException(status_code=400, detail="Unable to transfer admin") from None

    if updated_link is None:
        raise HTTPException(status_code=404, detail="Target user is not linked to this patient")
    return updated_link


@router.get("/{user_id}/patients", response_model=list[schemas.Patient])
def read_family_user_patients(
    user_id: int,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role not in {"doctor", "family"}:
        raise HTTPException(status_code=403, detail="Not allowed")

    family_user = cruds.get_user(db, user_id)
    if family_user is None or family_user.role != "family":
        raise HTTPException(status_code=404, detail="Family user not found")

    return cruds.get_patients_by_family_user(db=db, user_id=user_id, skip=skip, limit=limit)


@router.put(
    "/{user_id}/patients/{patient_id}/role",
    response_model=schemas.FamilyPatientLink,
)
def update_family_role(
    user_id: int,
    patient_id: int,
    payload: schemas.FamilyPatientRoleUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    family_user = cruds.get_user(db, user_id)
    if family_user is None or family_user.role != "family":
        raise HTTPException(status_code=404, detail="Family user not found")

    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    target_link = cruds.get_family_patient_link(db, user_id=user_id, patient_id=patient_id)
    if target_link is None:
        raise HTTPException(status_code=404, detail="Family-patient link not found")

    if current_user.role != "doctor":
        requester_link = cruds.get_family_patient_link(db, current_user.id, patient_id)
        if requester_link is None or requester_link.family_role != "admin":
            raise HTTPException(status_code=403, detail="Only family admin can update roles")

    if payload.family_role == "admin":
        try:
            updated_link = cruds.transfer_family_admin(
                db=db,
                patient_id=patient_id,
                new_admin_user_id=user_id,
            )
        except IntegrityError:
            raise HTTPException(status_code=409, detail="Unable to update family role") from None
        if updated_link is None:
            raise HTTPException(status_code=404, detail="Family-patient link not found")
        return updated_link

    if target_link.family_role == "admin":
        raise HTTPException(
            status_code=400,
            detail="Cannot demote current admin directly. Transfer admin first.",
        )

    try:
        return cruds.update_family_patient_role(
            db=db,
            link=target_link,
            family_role=payload.family_role,
        )
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Unable to update family role") from None


@router.delete(
    "/{user_id}/patients/{patient_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def unlink_family_from_patient(
    user_id: int,
    patient_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    family_user = cruds.get_user(db, user_id)
    if family_user is None or family_user.role != "family":
        raise HTTPException(status_code=404, detail="Family user not found")

    patient = cruds.get_patient(db, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    target_link = cruds.get_family_patient_link(db, user_id=user_id, patient_id=patient_id)
    if target_link is None:
        raise HTTPException(status_code=404, detail="Family-patient link not found")

    if current_user.role != "doctor":
        requester_link = cruds.get_family_patient_link(db, current_user.id, patient_id)
        if requester_link is None or requester_link.family_role != "admin":
            raise HTTPException(status_code=403, detail="Only family admin can unlink members")

    if target_link.family_role == "admin":
        raise HTTPException(
            status_code=400,
            detail="Cannot remove current admin directly. Transfer admin first.",
        )

    try:
        cruds.delete_family_patient_link(db=db, user_id=user_id, patient_id=patient_id)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Unable to delete family-patient link") from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)
