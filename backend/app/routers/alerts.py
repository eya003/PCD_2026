from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_db

router = APIRouter()


@router.post("/", response_model=schemas.Alert, status_code=status.HTTP_201_CREATED)
def create_alert(payload: schemas.AlertCreate, db: Session = Depends(get_db)):
    patient = cruds.get_patient(db, payload.patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")

    try:
        return cruds.create_alert(db=db, payload=payload)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Alert conflict") from None


@router.get("/", response_model=list[schemas.Alert])
def read_alerts(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return cruds.get_alerts(db=db, skip=skip, limit=limit)


@router.get("/{alert_id}", response_model=schemas.Alert)
def read_alert(alert_id: int, db: Session = Depends(get_db)):
    alert = cruds.get_alert(db, alert_id)
    if alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")
    return alert


@router.put("/{alert_id}", response_model=schemas.Alert)
def update_alert(
    alert_id: int,
    payload: schemas.AlertUpdate,
    db: Session = Depends(get_db),
):
    db_alert = cruds.get_alert(db, alert_id)
    if db_alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")

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
def mark_alert_as_read(alert_id: int, db: Session = Depends(get_db)):
    db_alert = cruds.get_alert(db, alert_id)
    if db_alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")

    if db_alert.is_read:
        return db_alert

    try:
        return cruds.mark_alert_as_read(db=db, db_alert=db_alert)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Alert conflict") from None


@router.delete("/{alert_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_alert(alert_id: int, db: Session = Depends(get_db)):
    db_alert = cruds.get_alert(db, alert_id)
    if db_alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")

    try:
        cruds.delete_alert(db=db, db_alert=db_alert)
    except IntegrityError:
        raise HTTPException(status_code=409, detail="Unable to delete alert") from None
    return Response(status_code=status.HTTP_204_NO_CONTENT)
