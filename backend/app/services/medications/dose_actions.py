from datetime import datetime

from sqlalchemy.orm import Session

from ... import models
from . import notifications

DOSE_STATUS_PENDING = "pending"
DOSE_STATUS_TAKEN = "taken"
DOSE_STATUS_MISSED = "missed"
DOSE_STATUS_SKIPPED = "skipped"
DOSE_STATUS_RESCHEDULED = "rescheduled"
DOSE_STATUS_CANCELLED = "cancelled"

INTAKE_STATUS_TAKEN = "taken"
INTAKE_STATUS_MISSED = "missed"
INTAKE_STATUS_SKIPPED = "skipped"
INTAKE_STATUS_RESCHEDULED = "rescheduled"


class DoseTransitionError(ValueError):
    """Raised when dose transition request is invalid."""


def _append_note(existing: str | None, note: str | None) -> str | None:
    if note is None:
        return existing
    clean = note.strip()
    if not clean:
        return existing
    if not existing:
        return clean
    return f"{existing}\n{clean}"


def _create_intake_log(
    db: Session,
    *,
    dose: models.ScheduledMedicationDose,
    status: str,
    acted_by: int | None,
    acted_at: datetime,
    comment: str | None,
) -> models.MedicationIntake:
    intake = models.MedicationIntake(
        medication_id=dose.medication_id,
        scheduled_dose_id=dose.id,
        scheduled_for=dose.scheduled_for,
        taken_at=acted_at,
        status=status,
        validated_by=acted_by,
        comment=comment,
    )
    db.add(intake)
    db.flush()
    return intake


def _upsert_rescheduled_successor(
    db: Session,
    *,
    dose: models.ScheduledMedicationDose,
    rescheduled_for: datetime,
) -> models.ScheduledMedicationDose:
    successor = (
        db.query(models.ScheduledMedicationDose)
        .filter(models.ScheduledMedicationDose.medication_id == dose.medication_id)
        .filter(models.ScheduledMedicationDose.scheduled_for == rescheduled_for)
        .first()
    )
    if successor is None:
        successor = models.ScheduledMedicationDose(
            patient_id=dose.patient_id,
            medication_id=dose.medication_id,
            prescription_id=dose.prescription_id,
            scheduled_date=rescheduled_for.date(),
            scheduled_time=rescheduled_for.time().replace(microsecond=0),
            scheduled_for=rescheduled_for.replace(microsecond=0),
            period_label=dose.period_label,
            status=DOSE_STATUS_PENDING,
            original_scheduled_for=dose.scheduled_for,
            rescheduled_for=None,
            taken_at=None,
            validated_by=None,
            validation_method="system",
            skipped_reason=None,
            notes="Generated automatically from rescheduled dose",
        )
        db.add(successor)
        db.flush()
    else:
        successor.patient_id = dose.patient_id
        successor.prescription_id = dose.prescription_id
        successor.scheduled_date = rescheduled_for.date()
        successor.scheduled_time = rescheduled_for.time().replace(microsecond=0)
        if successor.original_scheduled_for is None:
            successor.original_scheduled_for = dose.scheduled_for
        if successor.status == DOSE_STATUS_CANCELLED:
            successor.status = DOSE_STATUS_PENDING
            successor.taken_at = None
            successor.validated_by = None
            successor.validation_method = "system"
            successor.skipped_reason = None
            successor.notes = _append_note(
                successor.notes,
                "Reactivated automatically from rescheduled dose",
            )

    notifications.upsert_pending_notification_for_dose(db, successor)
    return successor


def transition_scheduled_dose_status(
    db: Session,
    *,
    dose: models.ScheduledMedicationDose,
    target_status: str,
    acted_by: int | None = None,
    acted_at: datetime | None = None,
    validation_method: str = "manual",
    skipped_reason: str | None = None,
    notes: str | None = None,
    comment: str | None = None,
    rescheduled_for: datetime | None = None,
    create_intake_log: bool = True,
) -> tuple[models.ScheduledMedicationDose, models.MedicationIntake | None]:
    normalized_target_status = (target_status or "").strip().lower()

    if dose.status != DOSE_STATUS_PENDING:
        raise DoseTransitionError(
            f"Invalid transition: only '{DOSE_STATUS_PENDING}' doses can be transitioned"
        )

    allowed_targets = {
        DOSE_STATUS_TAKEN,
        DOSE_STATUS_MISSED,
        DOSE_STATUS_SKIPPED,
        DOSE_STATUS_RESCHEDULED,
        DOSE_STATUS_CANCELLED,
    }
    if normalized_target_status not in allowed_targets:
        raise DoseTransitionError(
            f"Invalid target status '{normalized_target_status}'. Expected one of {sorted(allowed_targets)}"
        )

    action_time = (acted_at or datetime.utcnow()).replace(microsecond=0)
    intake: models.MedicationIntake | None = None

    if normalized_target_status == DOSE_STATUS_TAKEN:
        dose.status = DOSE_STATUS_TAKEN
        dose.taken_at = action_time
        dose.rescheduled_for = None
        dose.skipped_reason = None
        dose.validated_by = acted_by
        dose.validation_method = validation_method
        dose.notes = _append_note(dose.notes, notes)
        notifications.cancel_pending_notifications_for_dose(
            db,
            dose.id,
            reason="Dose marked as taken",
        )
        if create_intake_log:
            intake = _create_intake_log(
                db,
                dose=dose,
                status=INTAKE_STATUS_TAKEN,
                acted_by=acted_by,
                acted_at=action_time,
                comment=comment,
            )

    elif normalized_target_status == DOSE_STATUS_MISSED:
        dose.status = DOSE_STATUS_MISSED
        dose.taken_at = None
        dose.rescheduled_for = None
        dose.skipped_reason = None
        dose.validated_by = acted_by
        dose.validation_method = validation_method
        dose.notes = _append_note(dose.notes, notes)
        notifications.cancel_pending_notifications_for_dose(
            db,
            dose.id,
            reason="Dose marked as missed",
        )
        if create_intake_log:
            intake = _create_intake_log(
                db,
                dose=dose,
                status=INTAKE_STATUS_MISSED,
                acted_by=acted_by,
                acted_at=action_time,
                comment=comment,
            )

    elif normalized_target_status == DOSE_STATUS_SKIPPED:
        if skipped_reason is None or not skipped_reason.strip():
            raise DoseTransitionError("skipped_reason is required when status='skipped'")
        dose.status = DOSE_STATUS_SKIPPED
        dose.taken_at = None
        dose.rescheduled_for = None
        dose.validated_by = acted_by
        dose.validation_method = validation_method
        dose.skipped_reason = skipped_reason.strip()
        dose.notes = _append_note(dose.notes, notes)
        notifications.cancel_pending_notifications_for_dose(
            db,
            dose.id,
            reason="Dose skipped",
        )
        if create_intake_log:
            intake = _create_intake_log(
                db,
                dose=dose,
                status=INTAKE_STATUS_SKIPPED,
                acted_by=acted_by,
                acted_at=action_time,
                comment=comment or skipped_reason,
            )

    elif normalized_target_status == DOSE_STATUS_RESCHEDULED:
        if rescheduled_for is None:
            raise DoseTransitionError("rescheduled_for is required when status='rescheduled'")
        new_slot = rescheduled_for.replace(microsecond=0)
        now_utc = datetime.utcnow().replace(microsecond=0)
        if new_slot <= max(action_time, now_utc):
            raise DoseTransitionError("rescheduled_for must be in the future")

        dose.status = DOSE_STATUS_RESCHEDULED
        dose.taken_at = None
        dose.validated_by = acted_by
        dose.validation_method = validation_method
        dose.skipped_reason = None
        dose.original_scheduled_for = dose.original_scheduled_for or dose.scheduled_for
        dose.rescheduled_for = new_slot
        dose.notes = _append_note(dose.notes, notes)
        notifications.cancel_pending_notifications_for_dose(
            db,
            dose.id,
            reason="Dose rescheduled",
        )

        _upsert_rescheduled_successor(db, dose=dose, rescheduled_for=new_slot)

        if create_intake_log:
            intake = _create_intake_log(
                db,
                dose=dose,
                status=INTAKE_STATUS_RESCHEDULED,
                acted_by=acted_by,
                acted_at=action_time,
                comment=comment,
            )

    elif normalized_target_status == DOSE_STATUS_CANCELLED:
        dose.status = DOSE_STATUS_CANCELLED
        dose.taken_at = None
        dose.rescheduled_for = None
        dose.skipped_reason = None
        dose.validated_by = acted_by
        dose.validation_method = validation_method
        dose.notes = _append_note(dose.notes, notes)
        notifications.cancel_pending_notifications_for_dose(
            db,
            dose.id,
            reason="Dose cancelled",
        )

    return dose, intake
