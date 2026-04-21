from datetime import timedelta

from sqlalchemy.orm import Session

from ... import models

DEFAULT_REMINDER_OFFSET_MINUTES = 10
NOTIFICATION_CHANNEL_LOCAL = "local"
NOTIFICATION_STATUS_PENDING = "pending"
NOTIFICATION_STATUS_CANCELLED = "cancelled"


def get_default_reminder_offset_minutes(db: Session, patient_id: int) -> int:
    template = (
        db.query(models.MedicationScheduleTemplate)
        .filter(models.MedicationScheduleTemplate.patient_id == patient_id)
        .filter(models.MedicationScheduleTemplate.is_active.is_(True))
        .first()
    )
    if template is None or template.reminder_offset_minutes is None:
        return DEFAULT_REMINDER_OFFSET_MINUTES
    return max(0, int(template.reminder_offset_minutes))


def upsert_pending_notification_for_dose(
    db: Session,
    dose: models.ScheduledMedicationDose,
    *,
    channel: str = NOTIFICATION_CHANNEL_LOCAL,
    reminder_offset_minutes: int | None = None,
) -> models.DoseNotification | None:
    if dose.status != "pending":
        return None

    offset = (
        reminder_offset_minutes
        if reminder_offset_minutes is not None
        else get_default_reminder_offset_minutes(db, dose.patient_id)
    )
    send_at = dose.scheduled_for - timedelta(minutes=max(0, offset))

    notification = (
        db.query(models.DoseNotification)
        .filter(models.DoseNotification.scheduled_dose_id == dose.id)
        .filter(models.DoseNotification.channel == channel)
        .filter(models.DoseNotification.status == NOTIFICATION_STATUS_PENDING)
        .first()
    )
    if notification is None:
        notification = models.DoseNotification(
            scheduled_dose_id=dose.id,
            patient_id=dose.patient_id,
            recipient_user_id=None,
            channel=channel,
            send_at=send_at,
            status=NOTIFICATION_STATUS_PENDING,
            error_message=None,
        )
        db.add(notification)
        db.flush()
    else:
        notification.send_at = send_at
        notification.error_message = None

    return notification


def cancel_pending_notifications_for_dose(
    db: Session,
    dose_id: int,
    *,
    reason: str | None = None,
) -> int:
    notifications = (
        db.query(models.DoseNotification)
        .filter(models.DoseNotification.scheduled_dose_id == dose_id)
        .filter(models.DoseNotification.status == NOTIFICATION_STATUS_PENDING)
        .all()
    )
    for notification in notifications:
        notification.status = NOTIFICATION_STATUS_CANCELLED
        notification.error_message = reason
    return len(notifications)

