import json
import re
from datetime import date, datetime, time, timedelta

from sqlalchemy.orm import Session

from ... import models
from . import notifications

DEFAULT_DAY_START = time(8, 0)
DEFAULT_DAY_END = time(23, 0)
DEFAULT_TEMPLATE_TIMES = [time(8, 0), time(13, 0), time(20, 0)]
DEFAULT_SCHEDULE_HORIZON_DAYS = 30
DOSE_STATUS_PENDING = "pending"
DOSE_STATUS_RESCHEDULED = "rescheduled"
DOSE_STATUS_CANCELLED = "cancelled"
MEDICATION_STATUS_COMPLETED = "completed"
MEDICATION_STATUS_STOPPED = "stopped"
SCHEDULE_MODE_FIXED_TIMES = "fixed_times"
SCHEDULE_MODE_DEFAULT_TIMES = "default_times"
SCHEDULE_MODE_DISTRIBUTED = "distributed"


def _time_to_seconds(value: time) -> int:
    return value.hour * 3600 + value.minute * 60 + value.second


def _seconds_to_time(value: int) -> time:
    clamped = max(0, min(86399, int(value)))
    hours = clamped // 3600
    minutes = (clamped % 3600) // 60
    seconds = clamped % 60
    return time(hour=hours, minute=minutes, second=seconds)


def _parse_time_value(value: object) -> time | None:
    if value is None:
        return None
    if isinstance(value, time):
        return value.replace(microsecond=0)
    if isinstance(value, datetime):
        return value.time().replace(microsecond=0)
    if isinstance(value, str):
        raw = value.strip()
        if not raw:
            return None
        for fmt in ("%H:%M:%S", "%H:%M"):
            try:
                return datetime.strptime(raw, fmt).time()
            except ValueError:
                continue
    return None


def normalize_specific_times(raw_specific_times: object) -> list[time]:
    if raw_specific_times is None:
        return []

    values: list[object]
    if isinstance(raw_specific_times, list):
        values = raw_specific_times
    elif isinstance(raw_specific_times, tuple):
        values = list(raw_specific_times)
    elif isinstance(raw_specific_times, str):
        text_value = raw_specific_times.strip()
        if not text_value:
            return []
        try:
            parsed = json.loads(text_value)
            if isinstance(parsed, list):
                values = parsed
            else:
                values = [raw_specific_times]
        except ValueError:
            values = [raw_specific_times]
    else:
        values = [raw_specific_times]

    normalized: list[time] = []
    seen: set[int] = set()
    for value in values:
        parsed = _parse_time_value(value)
        if parsed is None:
            continue
        key = _time_to_seconds(parsed)
        if key in seen:
            continue
        seen.add(key)
        normalized.append(parsed)

    normalized.sort(key=_time_to_seconds)
    return normalized


def serialize_specific_times(raw_specific_times: object) -> list[str] | None:
    normalized = normalize_specific_times(raw_specific_times)
    if not normalized:
        return None
    return [value.strftime("%H:%M:%S") for value in normalized]


def _extract_specific_times_from_frequency(frequency: str | None) -> list[time]:
    if frequency is None:
        return []
    matches = re.findall(r"\b([01]?\d|2[0-3]):([0-5]\d)\b", frequency)
    if not matches:
        return []

    parsed = [time(hour=int(hour), minute=int(minute)) for hour, minute in matches]
    unique_sorted = sorted({value for value in parsed}, key=_time_to_seconds)
    return unique_sorted


def _extract_hour_interval_from_frequency(frequency: str | None) -> int | None:
    if frequency is None:
        return None

    lowered = frequency.lower()
    patterns = [
        r"\bq\s*(\d{1,2})\s*h\b",
        r"\bevery\s*(\d{1,2})\s*h(?:ours?)?\b",
        r"\btoutes?\s+les\s+(\d{1,2})\s*h(?:eures?)?\b",
        r"\bchaque\s*(\d{1,2})\s*h(?:eures?)?\b",
    ]
    for pattern in patterns:
        match = re.search(pattern, lowered)
        if not match:
            continue
        hours = int(match.group(1))
        if hours > 0:
            return hours
    return None


def _extract_daily_count_from_frequency(frequency: str | None) -> int | None:
    if frequency is None:
        return None

    lowered = frequency.lower().strip()

    if lowered in {
        "daily",
        "once daily",
        "once a day",
        "quotidien",
        "quotidienne",
        "chaque jour",
        "1/j",
        "1x/j",
    }:
        return 1
    if lowered in {"twice daily", "bid", "2/j", "2x/j"}:
        return 2
    if lowered in {"three times daily", "tid", "3/j", "3x/j"}:
        return 3
    if lowered in {"four times daily", "qid", "4/j", "4x/j"}:
        return 4

    match = re.search(
        r"\b(\d{1,2})\s*(?:x|fois|prises?)?\s*(?:/|par)?\s*(?:jour|day|daily|j)\b",
        lowered,
    )
    if match:
        count = int(match.group(1))
        if count > 0:
            return count
    return None


def _infer_intake_count_and_mode(
    frequency: str | None,
) -> tuple[int | None, str | None, list[time]]:
    specific_times = _extract_specific_times_from_frequency(frequency)
    if specific_times:
        return len(specific_times), SCHEDULE_MODE_FIXED_TIMES, specific_times

    hour_interval = _extract_hour_interval_from_frequency(frequency)
    if hour_interval:
        count = max(1, int(round(24 / hour_interval)))
        return count, SCHEDULE_MODE_DISTRIBUTED, []

    daily_count = _extract_daily_count_from_frequency(frequency)
    if daily_count:
        return daily_count, SCHEDULE_MODE_DEFAULT_TIMES, []

    return None, None, []


def _parse_duration_days_from_period(period: str | None) -> int | None:
    if period is None:
        return None

    lowered = period.lower().strip()
    if not lowered:
        return None

    plain_number = re.fullmatch(r"(\d{1,4})", lowered)
    if plain_number:
        value = int(plain_number.group(1))
        return value if value > 0 else None

    day_match = re.search(r"\b(\d{1,4})\s*(?:j|jour|jours|day|days)\b", lowered)
    if day_match:
        value = int(day_match.group(1))
        return value if value > 0 else None

    week_match = re.search(
        r"\b(\d{1,3})\s*(?:sem|semaine|semaines|week|weeks)\b",
        lowered,
    )
    if week_match:
        value = int(week_match.group(1))
        return (value * 7) if value > 0 else None

    month_match = re.search(r"\b(\d{1,3})\s*(?:mois|month|months)\b", lowered)
    if month_match:
        value = int(month_match.group(1))
        return (value * 30) if value > 0 else None

    return None


def derive_medication_planning_fields(
    db: Session,
    *,
    patient_id: int | None,
    frequency: str | None,
    period: str | None,
    start_date: date | None,
    end_date: date | None,
    is_as_needed: bool,
    intake_count_per_day: int | None = None,
    duration_days: int | None = None,
    schedule_mode: str | None = None,
    specific_times: object = None,
    day_start_time: time | None = None,
    day_end_time: time | None = None,
    allow_family_adjustment: bool | None = None,
) -> dict[str, object]:
    resolved_count = (
        int(intake_count_per_day)
        if intake_count_per_day is not None and int(intake_count_per_day) > 0
        else None
    )
    normalized_specific_times = normalize_specific_times(specific_times)
    inferred_count, inferred_mode, inferred_specific_times = _infer_intake_count_and_mode(
        frequency
    )

    if not normalized_specific_times and inferred_specific_times:
        normalized_specific_times = inferred_specific_times

    resolved_mode = schedule_mode or inferred_mode or SCHEDULE_MODE_DEFAULT_TIMES
    if is_as_needed and schedule_mode is None:
        resolved_mode = SCHEDULE_MODE_DEFAULT_TIMES

    if resolved_mode == SCHEDULE_MODE_FIXED_TIMES and not normalized_specific_times:
        resolved_mode = SCHEDULE_MODE_DEFAULT_TIMES

    if normalized_specific_times:
        resolved_count = resolved_count or len(normalized_specific_times)
    else:
        resolved_count = resolved_count or inferred_count or 3

    resolved_duration = (
        int(duration_days)
        if duration_days is not None and int(duration_days) > 0
        else None
    )
    if resolved_duration is None and start_date is not None and end_date is not None:
        resolved_duration = max(1, (end_date - start_date).days + 1)
    if resolved_duration is None:
        resolved_duration = _parse_duration_days_from_period(period)

    template = _resolve_template(db, patient_id)
    resolved_day_start = day_start_time
    resolved_day_end = day_end_time
    if template is not None:
        if resolved_day_start is None:
            resolved_day_start = template.day_start_time
        if resolved_day_end is None:
            resolved_day_end = template.day_end_time

    if allow_family_adjustment is None:
        resolved_allow_family_adjustment = (
            template.allow_family_adjustment if template is not None else True
        )
    else:
        resolved_allow_family_adjustment = bool(allow_family_adjustment)

    if is_as_needed:
        resolved_specific_serialized = None
    else:
        resolved_specific_serialized = serialize_specific_times(normalized_specific_times)

    return {
        "intake_count_per_day": resolved_count,
        "duration_days": resolved_duration,
        "schedule_mode": resolved_mode,
        "specific_times": resolved_specific_serialized,
        "day_start_time": resolved_day_start,
        "day_end_time": resolved_day_end,
        "allow_family_adjustment": resolved_allow_family_adjustment,
    }


def _append_note(existing: str | None, note: str) -> str:
    clean_note = note.strip()
    if not clean_note:
        return existing or ""
    if not existing:
        return clean_note
    return f"{existing}\n{clean_note}"


def _resolve_intake_count(
    medication: models.Medication,
    specific_times: list[time],
) -> int:
    if medication.intake_count_per_day is not None and medication.intake_count_per_day > 0:
        return int(medication.intake_count_per_day)
    if specific_times:
        return len(specific_times)
    if medication.schedule_mode in {"fixed_times", "default_times"}:
        return 3
    return 1


def _pick_evenly_spaced(base_times: list[time], count: int) -> list[time]:
    if count <= 0:
        return []
    if len(base_times) <= count:
        return base_times
    if count == 1:
        return [base_times[0]]

    picks: list[time] = []
    max_index = len(base_times) - 1
    for i in range(count):
        idx = round((i * max_index) / (count - 1))
        picks.append(base_times[idx])
    return sorted({value for value in picks}, key=_time_to_seconds)


def _distribute_times(count: int, start: time, end: time) -> list[time]:
    if count <= 0:
        return []

    start_seconds = _time_to_seconds(start)
    end_seconds = _time_to_seconds(end)
    if end_seconds <= start_seconds:
        end_seconds = min(86399, start_seconds + (15 * 3600))
        if end_seconds <= start_seconds:
            end_seconds = min(86399, start_seconds + 3600)

    if count == 1:
        return [_seconds_to_time(start_seconds)]

    step = (end_seconds - start_seconds) / (count - 1)
    return [_seconds_to_time(round(start_seconds + (step * i))) for i in range(count)]


def _resolve_template(db: Session, patient_id: int | None) -> models.MedicationScheduleTemplate | None:
    if patient_id is None:
        return None
    return (
        db.query(models.MedicationScheduleTemplate)
        .filter(models.MedicationScheduleTemplate.patient_id == patient_id)
        .filter(models.MedicationScheduleTemplate.is_active.is_(True))
        .first()
    )


def _resolve_default_times(template: models.MedicationScheduleTemplate | None) -> list[time]:
    if template is None:
        return DEFAULT_TEMPLATE_TIMES
    resolved: list[time] = []
    for value in [template.morning_time, template.noon_time, template.evening_time]:
        parsed = _parse_time_value(value)
        if parsed is not None:
            resolved.append(parsed)
    if not resolved:
        return DEFAULT_TEMPLATE_TIMES
    return sorted({value for value in resolved}, key=_time_to_seconds)


def _resolve_day_window(
    medication: models.Medication,
    template: models.MedicationScheduleTemplate | None,
) -> tuple[time, time]:
    day_start = _parse_time_value(medication.day_start_time)
    day_end = _parse_time_value(medication.day_end_time)

    if day_start is None and template is not None:
        day_start = _parse_time_value(template.day_start_time)
    if day_end is None and template is not None:
        day_end = _parse_time_value(template.day_end_time)

    start = day_start or DEFAULT_DAY_START
    end = day_end or DEFAULT_DAY_END
    return start, end


def _resolve_daily_times(
    medication: models.Medication,
    template: models.MedicationScheduleTemplate | None,
) -> list[time]:
    specific_times = normalize_specific_times(medication.specific_times)
    intake_count = _resolve_intake_count(medication, specific_times)
    day_start, day_end = _resolve_day_window(medication, template)
    schedule_mode = medication.schedule_mode or "default_times"

    if schedule_mode == "fixed_times":
        if specific_times:
            # Fixed mode prioritizes explicit configured times.
            if len(specific_times) <= intake_count:
                return specific_times
            if len(specific_times) > intake_count:
                return _pick_evenly_spaced(specific_times, intake_count)
        return _distribute_times(intake_count, day_start, day_end)

    if schedule_mode == "distributed":
        return _distribute_times(intake_count, day_start, day_end)

    default_times = _resolve_default_times(template)
    if len(default_times) == intake_count:
        return default_times
    if len(default_times) > intake_count:
        return _pick_evenly_spaced(default_times, intake_count)
    return _distribute_times(intake_count, day_start, day_end)


def _resolve_generation_bounds(
    medication: models.Medication,
    *,
    today: date,
    horizon_days: int,
) -> tuple[date, date] | None:
    if medication.patient_id is None:
        return None
    if medication.is_as_needed:
        return None
    if medication.status in {MEDICATION_STATUS_COMPLETED, MEDICATION_STATUS_STOPPED}:
        return None

    start_date = medication.start_date or today
    if medication.end_date is not None:
        end_date = medication.end_date
    elif medication.duration_days is not None and medication.duration_days > 0:
        end_date = start_date + timedelta(days=int(medication.duration_days) - 1)
    else:
        end_date = today + timedelta(days=max(1, horizon_days))

    generation_start = max(start_date, today)
    if end_date < generation_start:
        return None
    return generation_start, end_date


def build_target_schedule_slots(
    db: Session,
    medication: models.Medication,
    *,
    from_datetime: datetime | None = None,
    horizon_days: int = DEFAULT_SCHEDULE_HORIZON_DAYS,
) -> list[datetime]:
    now = (from_datetime or datetime.utcnow()).replace(microsecond=0)
    bounds = _resolve_generation_bounds(
        medication,
        today=now.date(),
        horizon_days=horizon_days,
    )
    if bounds is None:
        return []

    template = _resolve_template(db, medication.patient_id)
    daily_times = _resolve_daily_times(medication, template)
    if not daily_times:
        return []

    start_date, end_date = bounds
    slots: list[datetime] = []
    day = start_date
    while day <= end_date:
        for value in daily_times:
            slot = datetime.combine(day, value).replace(microsecond=0)
            if slot >= now:
                slots.append(slot)
        day += timedelta(days=1)

    unique_slots = sorted(set(slots))
    return unique_slots


def cancel_future_doses_for_medication(
    db: Session,
    medication: models.Medication,
    *,
    reason: str | None = None,
    acted_by: int | None = None,
    from_datetime: datetime | None = None,
) -> int:
    now = (from_datetime or datetime.utcnow()).replace(microsecond=0)
    cancellable = (
        db.query(models.ScheduledMedicationDose)
        .filter(models.ScheduledMedicationDose.medication_id == medication.id)
        .filter(models.ScheduledMedicationDose.scheduled_for >= now)
        .filter(models.ScheduledMedicationDose.status.in_([DOSE_STATUS_PENDING, DOSE_STATUS_RESCHEDULED]))
        .all()
    )

    for dose in cancellable:
        dose.status = DOSE_STATUS_CANCELLED
        dose.validated_by = acted_by
        dose.validation_method = "system"
        if reason:
            dose.notes = _append_note(dose.notes, reason)
        notifications.cancel_pending_notifications_for_dose(
            db,
            dose.id,
            reason=reason or "Dose cancelled by medication state update",
        )

    return len(cancellable)


def synchronize_future_doses(
    db: Session,
    medication: models.Medication,
    *,
    from_datetime: datetime | None = None,
    horizon_days: int = DEFAULT_SCHEDULE_HORIZON_DAYS,
    cancel_missing: bool = True,
) -> dict[str, int]:
    now = (from_datetime or datetime.utcnow()).replace(microsecond=0)
    stats = {
        "created": 0,
        "updated": 0,
        "cancelled": 0,
        "reactivated": 0,
    }

    existing_future = (
        db.query(models.ScheduledMedicationDose)
        .filter(models.ScheduledMedicationDose.medication_id == medication.id)
        .filter(models.ScheduledMedicationDose.scheduled_for >= now)
        .order_by(models.ScheduledMedicationDose.scheduled_for.asc())
        .all()
    )
    existing_by_slot = {dose.scheduled_for.replace(microsecond=0): dose for dose in existing_future}

    target_slots = build_target_schedule_slots(
        db,
        medication,
        from_datetime=now,
        horizon_days=horizon_days,
    )
    target_slot_set = set(target_slots)

    if cancel_missing:
        for dose in existing_future:
            slot = dose.scheduled_for.replace(microsecond=0)
            if slot in target_slot_set:
                continue
            if dose.status in {DOSE_STATUS_PENDING, DOSE_STATUS_RESCHEDULED}:
                dose.status = DOSE_STATUS_CANCELLED
                dose.validation_method = "system"
                dose.notes = _append_note(
                    dose.notes,
                    "Cancelled automatically after medication schedule recalculation",
                )
                notifications.cancel_pending_notifications_for_dose(
                    db,
                    dose.id,
                    reason="Cancelled by schedule recalculation",
                )
                stats["cancelled"] += 1

    for slot in target_slots:
        existing = existing_by_slot.get(slot)
        if existing is not None:
            if existing.status == DOSE_STATUS_CANCELLED:
                existing.status = DOSE_STATUS_PENDING
                existing.original_scheduled_for = None
                existing.rescheduled_for = None
                existing.skipped_reason = None
                existing.taken_at = None
                existing.validated_by = None
                existing.validation_method = "system"
                stats["reactivated"] += 1

            existing.patient_id = medication.patient_id
            existing.prescription_id = medication.prescription_id
            existing.scheduled_date = slot.date()
            existing.scheduled_time = slot.time().replace(microsecond=0)

            if existing.status == DOSE_STATUS_PENDING:
                notifications.upsert_pending_notification_for_dose(db, existing)
            stats["updated"] += 1
            continue

        new_dose = models.ScheduledMedicationDose(
            patient_id=medication.patient_id,
            medication_id=medication.id,
            prescription_id=medication.prescription_id,
            scheduled_date=slot.date(),
            scheduled_time=slot.time().replace(microsecond=0),
            scheduled_for=slot,
            period_label=None,
            status=DOSE_STATUS_PENDING,
            original_scheduled_for=None,
            rescheduled_for=None,
            taken_at=None,
            validated_by=None,
            validation_method="system",
            skipped_reason=None,
            notes=None,
        )
        db.add(new_dose)
        db.flush()
        notifications.upsert_pending_notification_for_dose(db, new_dose)
        stats["created"] += 1

    return stats
