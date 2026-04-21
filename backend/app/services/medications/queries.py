from datetime import date, datetime

from sqlalchemy.orm import Session, joinedload

from ... import models


def get_scheduled_dose(db: Session, dose_id: int) -> models.ScheduledMedicationDose | None:
    return (
        db.query(models.ScheduledMedicationDose)
        .options(
            joinedload(models.ScheduledMedicationDose.medication),
            joinedload(models.ScheduledMedicationDose.intakes),
            joinedload(models.ScheduledMedicationDose.notifications),
        )
        .filter(models.ScheduledMedicationDose.id == dose_id)
        .first()
    )


def get_patient_day_planning_doses(
    db: Session,
    *,
    patient_id: int,
    planning_date: date,
) -> list[models.ScheduledMedicationDose]:
    return (
        db.query(models.ScheduledMedicationDose)
        .options(joinedload(models.ScheduledMedicationDose.medication))
        .filter(models.ScheduledMedicationDose.patient_id == patient_id)
        .filter(models.ScheduledMedicationDose.scheduled_date == planning_date)
        .order_by(
            models.ScheduledMedicationDose.scheduled_for.asc(),
            models.ScheduledMedicationDose.id.asc(),
        )
        .all()
    )


def get_patient_range_planning_doses(
    db: Session,
    *,
    patient_id: int,
    start_date: date,
    end_date: date,
) -> list[models.ScheduledMedicationDose]:
    return (
        db.query(models.ScheduledMedicationDose)
        .options(joinedload(models.ScheduledMedicationDose.medication))
        .filter(models.ScheduledMedicationDose.patient_id == patient_id)
        .filter(models.ScheduledMedicationDose.scheduled_date >= start_date)
        .filter(models.ScheduledMedicationDose.scheduled_date <= end_date)
        .order_by(
            models.ScheduledMedicationDose.scheduled_for.asc(),
            models.ScheduledMedicationDose.id.asc(),
        )
        .all()
    )


def get_next_dose_for_medication(
    db: Session,
    *,
    medication_id: int,
    from_datetime: datetime | None = None,
) -> models.ScheduledMedicationDose | None:
    anchor = (from_datetime or datetime.utcnow()).replace(microsecond=0)
    return (
        db.query(models.ScheduledMedicationDose)
        .options(joinedload(models.ScheduledMedicationDose.medication))
        .filter(models.ScheduledMedicationDose.medication_id == medication_id)
        .filter(models.ScheduledMedicationDose.status == "pending")
        .filter(models.ScheduledMedicationDose.scheduled_for >= anchor)
        .order_by(models.ScheduledMedicationDose.scheduled_for.asc())
        .first()
    )


def get_scheduled_doses_for_medication(
    db: Session,
    *,
    medication_id: int,
    start_date: date | None = None,
    end_date: date | None = None,
) -> list[models.ScheduledMedicationDose]:
    query = (
        db.query(models.ScheduledMedicationDose)
        .options(
            joinedload(models.ScheduledMedicationDose.medication),
            joinedload(models.ScheduledMedicationDose.intakes),
            joinedload(models.ScheduledMedicationDose.notifications),
        )
        .filter(models.ScheduledMedicationDose.medication_id == medication_id)
    )
    if start_date is not None:
        query = query.filter(models.ScheduledMedicationDose.scheduled_date >= start_date)
    if end_date is not None:
        query = query.filter(models.ScheduledMedicationDose.scheduled_date <= end_date)

    return (
        query.order_by(
            models.ScheduledMedicationDose.scheduled_for.asc(),
            models.ScheduledMedicationDose.id.asc(),
        )
        .all()
    )


def build_status_counts(
    doses: list[models.ScheduledMedicationDose],
) -> dict[str, int]:
    counts = {
        "pending": 0,
        "taken": 0,
        "missed": 0,
        "skipped": 0,
        "rescheduled": 0,
        "cancelled": 0,
        "total": len(doses),
    }
    for dose in doses:
        status = (dose.status or "").lower()
        if status in counts:
            counts[status] += 1
    return counts
