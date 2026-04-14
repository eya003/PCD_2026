from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_current_user, get_db

router = APIRouter()


def _ensure_patient_access(
    db: Session,
    *,
    current_user,
    patient_id: int,
):
    if not cruds.can_user_access_patient(db, current_user, patient_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not allowed to access this patient",
        )


def _ensure_family_admin_manage_alerts(
    db: Session,
    *,
    current_user,
    patient_id: int,
):
    if current_user.role != "family":
        return

    requester_link = cruds.get_family_patient_link(
        db,
        user_id=current_user.id,
        patient_id=patient_id,
    )
    if requester_link is None or requester_link.family_role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family admin can manage alerts",
        )


@router.post("/", response_model=schemas.Alert, status_code=status.HTTP_201_CREATED)
def create_alert(
    payload: schemas.AlertCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    _ensure_patient_access(
        db,
        current_user=current_user,
        patient_id=payload.patient_id,
    )
    _ensure_family_admin_manage_alerts(
        db,
        current_user=current_user,
        patient_id=payload.patient_id,
    )

    try:
        return cruds.create_alert(db=db, payload=payload)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Alert conflict") from None


@router.get("/", response_model=list[schemas.Alert])
def read_alerts(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return cruds.get_alerts(db=db, skip=skip, limit=limit)


@router.get("/{alert_id}", response_model=schemas.Alert)
def read_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    alert = cruds.get_alert(db, alert_id)
    if alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")

    _ensure_patient_access(
        db,
        current_user=current_user,
        patient_id=alert.patient_id,
    )

    return alert


@router.put("/{alert_id}", response_model=schemas.Alert)
def update_alert(
    alert_id: int,
    payload: schemas.AlertUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db_alert = cruds.get_alert(db, alert_id)
    if db_alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")

    _ensure_patient_access(
        db,
        current_user=current_user,
        patient_id=db_alert.patient_id,
    )
    _ensure_family_admin_manage_alerts(
        db,
        current_user=current_user,
        patient_id=db_alert.patient_id,
    )

    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields provided for update")

    if payload.patient_id is not None:
        patient = cruds.get_patient(db, payload.patient_id)
        if patient is None:
            raise HTTPException(status_code=404, detail="Patient not found")

    try:
        return cruds.update_alert(db=db, db_alert=db_alert, payload=payload)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Alert conflict") from None


@router.patch("/{alert_id}/read", response_model=schemas.Alert)
def mark_alert_as_read(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db_alert = cruds.get_alert(db, alert_id)
    if db_alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")

    _ensure_patient_access(
        db,
        current_user=current_user,
        patient_id=db_alert.patient_id,
    )
    _ensure_family_admin_manage_alerts(
        db,
        current_user=current_user,
        patient_id=db_alert.patient_id,
    )

    if db_alert.is_read:
        return db_alert

    try:
        return cruds.mark_alert_as_read(db=db, db_alert=db_alert)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Alert conflict") from None


@router.delete("/{alert_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_alert(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db_alert = cruds.get_alert(db, alert_id)
    if db_alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")

    _ensure_patient_access(
        db,
        current_user=current_user,
        patient_id=db_alert.patient_id,
    )
    _ensure_family_admin_manage_alerts(
        db,
        current_user=current_user,
        patient_id=db_alert.patient_id,
    )

    try:
        cruds.delete_alert(db=db, db_alert=db_alert)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Unable to delete alert") from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)
