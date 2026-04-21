from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import cruds, schemas
from ..deps import get_current_user, get_db

router = APIRouter()


def _ensure_patient_read_access(
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


def _ensure_patient_write_access(
    db: Session,
    *,
    current_user,
    patient_id: int,
):
    if current_user.role == "doctor":
        if not cruds.is_doctor_linked_to_patient(
            db,
            doctor_id=current_user.id,
            patient_id=patient_id,
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Doctor is not linked to this patient",
            )
        return

    if current_user.role == "family":
        link = cruds.get_family_patient_link(
            db,
            user_id=current_user.id,
            patient_id=patient_id,
        )
        if link is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Family user is not linked to this patient",
            )
        if link.family_role != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only family admins can validate or adjust planned doses",
            )
        return

    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")


def _merge_reason_and_notes(reason: str | None, notes: str | None) -> str | None:
    if reason and notes:
        return f"{reason.strip()}\n{notes.strip()}"
    if reason:
        return reason.strip()
    if notes:
        return notes.strip()
    return None


@router.get(
    "/patients/{patient_id}/planning/today",
    response_model=schemas.DayPlanningRead,
)
def get_patient_today_planning(
    patient_id: int,
    planning_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_patient_read_access(db, current_user=current_user, patient_id=patient_id)
    try:
        return cruds.get_day_planning_for_patient(
            db,
            patient_id=patient_id,
            planning_date=planning_date or date.today(),
        )
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None


@router.get(
    "/patients/{patient_id}/planning",
    response_model=schemas.DateRangePlanningRead,
)
def get_patient_range_planning(
    patient_id: int,
    start_date: date = Query(...),
    end_date: date = Query(...),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_patient_read_access(db, current_user=current_user, patient_id=patient_id)
    try:
        return cruds.get_range_planning_for_patient(
            db,
            patient_id=patient_id,
            start_date=start_date,
            end_date=end_date,
        )
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None


@router.get(
    "/medications/{medication_id}/scheduled-doses",
    response_model=list[schemas.ScheduledMedicationDoseDetail],
)
def get_medication_scheduled_doses(
    medication_id: int,
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    medication = cruds.get_medication(db, medication_id)
    if medication is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Medication not found")

    _ensure_patient_read_access(
        db,
        current_user=current_user,
        patient_id=medication.patient_id,
    )
    try:
        return cruds.get_planned_doses_for_medication(
            db,
            medication_id=medication_id,
            start_date=start_date,
            end_date=end_date,
        )
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None


@router.get(
    "/scheduled-doses/{dose_id}",
    response_model=schemas.ScheduledMedicationDoseDetail,
)
def get_scheduled_dose_detail(
    dose_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db_dose = cruds.get_scheduled_medication_dose(db, dose_id)
    if db_dose is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scheduled dose not found",
        )

    _ensure_patient_read_access(
        db,
        current_user=current_user,
        patient_id=db_dose.patient_id,
    )
    return db_dose


@router.post(
    "/scheduled-doses/{dose_id}/take",
    response_model=schemas.ScheduledDoseActionResult,
)
def take_scheduled_dose(
    dose_id: int,
    payload: schemas.ScheduledDoseTakeAction,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db_dose = cruds.get_scheduled_medication_dose(db, dose_id)
    if db_dose is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scheduled dose not found",
        )
    _ensure_patient_write_access(db, current_user=current_user, patient_id=db_dose.patient_id)

    try:
        dose, intake = cruds.transition_planned_dose_status(
            db,
            db_dose=db_dose,
            target_status="taken",
            acted_by=current_user.id,
            acted_at=payload.taken_at,
            validation_method=payload.validation_method,
            notes=payload.notes,
            comment=payload.comment,
            create_intake_log=payload.create_intake_log,
        )
        return {"dose": dose, "intake": intake}
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unable to update scheduled dose",
        ) from None


@router.post(
    "/scheduled-doses/{dose_id}/miss",
    response_model=schemas.ScheduledDoseActionResult,
)
def miss_scheduled_dose(
    dose_id: int,
    payload: schemas.ScheduledDoseMissAction,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db_dose = cruds.get_scheduled_medication_dose(db, dose_id)
    if db_dose is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scheduled dose not found",
        )
    _ensure_patient_write_access(db, current_user=current_user, patient_id=db_dose.patient_id)

    try:
        dose, intake = cruds.transition_planned_dose_status(
            db,
            db_dose=db_dose,
            target_status="missed",
            acted_by=current_user.id,
            acted_at=payload.missed_at,
            validation_method=payload.validation_method,
            notes=payload.notes,
            comment=payload.comment,
            create_intake_log=payload.create_intake_log,
        )
        return {"dose": dose, "intake": intake}
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unable to update scheduled dose",
        ) from None


@router.post(
    "/scheduled-doses/{dose_id}/skip",
    response_model=schemas.ScheduledDoseActionResult,
)
def skip_scheduled_dose(
    dose_id: int,
    payload: schemas.ScheduledDoseSkipAction,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db_dose = cruds.get_scheduled_medication_dose(db, dose_id)
    if db_dose is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scheduled dose not found",
        )
    _ensure_patient_write_access(db, current_user=current_user, patient_id=db_dose.patient_id)

    try:
        dose, intake = cruds.transition_planned_dose_status(
            db,
            db_dose=db_dose,
            target_status="skipped",
            acted_by=current_user.id,
            acted_at=payload.skipped_at,
            validation_method=payload.validation_method,
            skipped_reason=payload.skipped_reason,
            notes=payload.notes,
            comment=payload.comment,
            create_intake_log=payload.create_intake_log,
        )
        return {"dose": dose, "intake": intake}
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unable to update scheduled dose",
        ) from None


@router.post(
    "/scheduled-doses/{dose_id}/reschedule",
    response_model=schemas.ScheduledDoseActionResult,
)
def reschedule_scheduled_dose(
    dose_id: int,
    payload: schemas.ScheduledDoseRescheduleAction,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db_dose = cruds.get_scheduled_medication_dose(db, dose_id)
    if db_dose is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scheduled dose not found",
        )
    _ensure_patient_write_access(db, current_user=current_user, patient_id=db_dose.patient_id)

    try:
        dose, intake = cruds.transition_planned_dose_status(
            db,
            db_dose=db_dose,
            target_status="rescheduled",
            acted_by=current_user.id,
            validation_method=payload.validation_method,
            rescheduled_for=payload.rescheduled_for,
            notes=_merge_reason_and_notes(payload.reason, payload.notes),
            comment=payload.reason,
            create_intake_log=True,
        )
        return {"dose": dose, "intake": intake}
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unable to update scheduled dose",
        ) from None


@router.post(
    "/scheduled-doses/{dose_id}/cancel",
    response_model=schemas.ScheduledDoseActionResult,
)
def cancel_scheduled_dose(
    dose_id: int,
    payload: schemas.ScheduledDoseCancelAction,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    db_dose = cruds.get_scheduled_medication_dose(db, dose_id)
    if db_dose is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scheduled dose not found",
        )
    _ensure_patient_write_access(db, current_user=current_user, patient_id=db_dose.patient_id)

    try:
        dose, intake = cruds.transition_planned_dose_status(
            db,
            db_dose=db_dose,
            target_status="cancelled",
            acted_by=current_user.id,
            validation_method="manual",
            notes=_merge_reason_and_notes(payload.reason, payload.notes),
            create_intake_log=False,
        )
        return {"dose": dose, "intake": intake}
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unable to update scheduled dose",
        ) from None


@router.get(
    "/patients/{patient_id}/schedule-template",
    response_model=schemas.MedicationScheduleTemplate,
)
def get_patient_schedule_template(
    patient_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_patient_read_access(db, current_user=current_user, patient_id=patient_id)
    try:
        return cruds.ensure_medication_schedule_template(
            db,
            patient_id=patient_id,
            created_by=None,
        )
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unable to fetch schedule template",
        ) from None


@router.put(
    "/patients/{patient_id}/schedule-template",
    response_model=schemas.MedicationScheduleTemplate,
)
def upsert_patient_schedule_template(
    patient_id: int,
    payload: schemas.MedicationScheduleTemplateUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    _ensure_patient_write_access(db, current_user=current_user, patient_id=patient_id)
    try:
        return cruds.upsert_medication_schedule_template(
            db,
            patient_id=patient_id,
            payload=payload,
            updated_by=current_user.id,
        )
    except cruds.BusinessRuleError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from None
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unable to update schedule template",
        ) from None
