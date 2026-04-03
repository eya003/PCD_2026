from datetime import date, datetime, timedelta

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from . import models, schemas
from .security import hash_password, verify_password


class BusinessRuleError(Exception):
    """Raised when a backend business rule is violated."""


class RoleConstraintError(BusinessRuleError):
    """Raised when trying to create a link with an invalid user role."""


class AdminConflictError(BusinessRuleError):
    """Raised when a patient already has a family admin."""


APPOINTMENT_STATUS_SCHEDULED = "scheduled"
APPOINTMENT_STATUS_DONE = "done"
APPOINTMENT_STATUS_CANCELLED = "cancelled"
APPOINTMENT_STATUS_MISSED = "missed"
PRESCRIPTION_STATUS_ACTIVE = "active"
PRESCRIPTION_STATUS_COMPLETED = "completed"
PRESCRIPTION_STATUS_CANCELLED = "cancelled"
MEDICATION_STATUS_ACTIVE = "active"
MEDICATION_STATUS_COMPLETED = "completed"
MEDICATION_STATUS_CANCELLED = "cancelled"
INTAKE_STATUS_TAKEN = "taken"
INTAKE_STATUS_MISSED = "missed"


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _normalize_cin(cin: str) -> str:
    return cin.strip().upper()


def _normalize_text(value: str) -> str:
    return value.strip()


def normalize_appointment_status(
    raw_status: str | None,
    *,
    default: str = APPOINTMENT_STATUS_SCHEDULED,
) -> str:
    if raw_status is None:
        return default

    status_value = raw_status.strip().lower()
    if not status_value:
        return default

    if status_value in {"scheduled", "planifie"}:
        return APPOINTMENT_STATUS_SCHEDULED
    if status_value in {"done", "completed", "termine"}:
        return APPOINTMENT_STATUS_DONE
    if status_value in {"cancelled", "canceled", "annule"}:
        return APPOINTMENT_STATUS_CANCELLED
    if status_value in {
        "missed",
        "manque",
    }:
        return APPOINTMENT_STATUS_MISSED

    raise BusinessRuleError(
        "Invalid appointment status. Expected 'scheduled', 'done', 'cancelled' or 'missed'"
    )


def normalize_prescription_status(
    raw_status: str | None,
    *,
    default: str = PRESCRIPTION_STATUS_ACTIVE,
) -> str:
    if raw_status is None:
        return default

    status_value = raw_status.strip().lower()
    if not status_value:
        return default

    if status_value in {"active", "actif"}:
        return PRESCRIPTION_STATUS_ACTIVE
    if status_value in {"completed", "done", "termine"}:
        return PRESCRIPTION_STATUS_COMPLETED
    if status_value in {"cancelled", "cancel", "annule"}:
        return PRESCRIPTION_STATUS_CANCELLED

    raise BusinessRuleError(
        "Invalid prescription status. Expected 'active', 'completed' or 'cancelled'"
    )


def normalize_medication_status(
    raw_status: str | None,
    *,
    default: str = MEDICATION_STATUS_ACTIVE,
) -> str:
    if raw_status is None:
        return default

    status_value = raw_status.strip().lower()
    if not status_value:
        return default

    if status_value in {"active", "actif"}:
        return MEDICATION_STATUS_ACTIVE
    if status_value in {"completed", "done", "termine"}:
        return MEDICATION_STATUS_COMPLETED
    if status_value in {"cancelled", "cancel", "annule"}:
        return MEDICATION_STATUS_CANCELLED

    raise BusinessRuleError(
        "Invalid medication status. Expected 'active', 'completed' or 'cancelled'"
    )


def normalize_intake_status(raw_status: str) -> str:
    status_value = raw_status.strip().lower()
    if status_value in {"taken", "pris"}:
        return INTAKE_STATUS_TAKEN
    if status_value in {"missed", "manque"}:
        return INTAKE_STATUS_MISSED
    raise BusinessRuleError("Invalid intake status. Expected 'taken' or 'missed'")


def _now_for_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return datetime.utcnow()
    return datetime.now(tz=value.tzinfo)


def _should_mark_appointment_as_missed(
    appointment_date: datetime,
    normalized_status: str,
) -> bool:
    if normalized_status in {
        APPOINTMENT_STATUS_DONE,
        APPOINTMENT_STATUS_CANCELLED,
        APPOINTMENT_STATUS_MISSED,
    }:
        return False
    return _now_for_datetime(appointment_date) >= (
        appointment_date + timedelta(days=1)
    )


def _apply_appointment_status_rules(db_appointment: models.Appointment) -> bool:
    normalized_status = normalize_appointment_status(db_appointment.status)
    status_changed = False

    if normalized_status != db_appointment.status:
        db_appointment.status = normalized_status
        status_changed = True

    if _should_mark_appointment_as_missed(
        db_appointment.appointment_date,
        normalized_status,
    ):
        if db_appointment.status != APPOINTMENT_STATUS_MISSED:
            db_appointment.status = APPOINTMENT_STATUS_MISSED
            status_changed = True

    return status_changed


def refresh_appointments_statuses(
    db: Session,
    appointments: list[models.Appointment],
) -> list[models.Appointment]:
    if not appointments:
        return appointments

    for appointment in appointments:
        _apply_appointment_status_rules(appointment)

    return appointments


def get_patient(db: Session, patient_id: int):
    return db.query(models.Patient).filter(models.Patient.id == patient_id).first()


def get_patient_by_code(db: Session, patient_code: str):
    return (
        db.query(models.Patient)
        .filter(models.Patient.patient_code == _normalize_text(patient_code))
        .first()
    )


def get_patient_by_cin(db: Session, cin: str):
    return (
        db.query(models.Patient)
        .filter(models.Patient.cin == _normalize_cin(cin))
        .first()
    )


def get_patient_by_identity(
    db: Session,
    first_name: str,
    last_name: str,
    birth_date: date,
):
    return (
        db.query(models.Patient)
        .filter(models.Patient.first_name == first_name.strip())
        .filter(models.Patient.last_name == last_name.strip())
        .filter(models.Patient.birth_date == birth_date)
        .first()
    )


def get_patients(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Patient).offset(skip).limit(limit).all()


def create_patient(
    db: Session,
    patient: schemas.PatientCreate,
    *,
    commit: bool = True,
):
    db_patient = models.Patient(
        patient_code=_normalize_text(patient.patient_code),
        first_name=_normalize_text(patient.first_name),
        last_name=_normalize_text(patient.last_name),
        birth_date=patient.birth_date,
        cin=_normalize_cin(patient.cin),
    )
    db.add(db_patient)
    if commit:
        try:
            db.commit()
            db.refresh(db_patient)
        except IntegrityError:
            db.rollback()
            raise
    else:
        db.flush()
    return db_patient


def get_user(db: Session, user_id: int):
    return db.query(models.User).filter(models.User.id == user_id).first()


def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == _normalize_email(email)).first()


def get_user_by_cin(db: Session, cin: str):
    return db.query(models.User).filter(models.User.cin == _normalize_cin(cin)).first()


def create_user(
    db: Session,
    *,
    first_name: str,
    last_name: str,
    cin: str,
    email: str,
    password: str,
    role: str,
    commit: bool = True,
):
    if role not in {"doctor", "family"}:
        raise BusinessRuleError("Invalid role. Expected 'doctor' or 'family'")

    db_user = models.User(
        first_name=_normalize_text(first_name),
        last_name=_normalize_text(last_name),
        cin=_normalize_cin(cin),
        email=_normalize_email(email),
        role=role,
        password_hash=hash_password(password),
    )
    db.add(db_user)
    if commit:
        try:
            db.commit()
            db.refresh(db_user)
        except IntegrityError:
            db.rollback()
            raise
    else:
        db.flush()
    return db_user


def authenticate_user(db: Session, cin: str, password: str):
    user = get_user_by_cin(db, cin)
    if user is None:
        return None
    if not verify_password(password, user.password_hash):
        return None
    return user


def get_doctor_patient_link(db: Session, doctor_id: int, patient_id: int):
    return (
        db.query(models.DoctorPatient)
        .filter(models.DoctorPatient.doctor_id == doctor_id)
        .filter(models.DoctorPatient.patient_id == patient_id)
        .first()
    )


def link_doctor_to_patient(
    db: Session,
    doctor_id: int,
    patient_id: int,
    *,
    commit: bool = True,
):
    doctor_user = get_user(db, doctor_id)
    if doctor_user is None or doctor_user.role != "doctor":
        raise RoleConstraintError(
            "Only users with role='doctor' can be linked in doctor_patient"
        )

    patient = get_patient(db, patient_id)
    if patient is None:
        raise BusinessRuleError("Patient not found")

    link = models.DoctorPatient(doctor_id=doctor_id, patient_id=patient_id)
    db.add(link)
    if commit:
        try:
            db.commit()
            db.refresh(link)
        except IntegrityError:
            db.rollback()
            raise
    else:
        db.flush()
    return link


def get_family_patient_link(db: Session, user_id: int, patient_id: int):
    return (
        db.query(models.FamilyPatient)
        .filter(models.FamilyPatient.user_id == user_id)
        .filter(models.FamilyPatient.patient_id == patient_id)
        .first()
    )


def get_family_admin_link(db: Session, patient_id: int):
    return (
        db.query(models.FamilyPatient)
        .filter(models.FamilyPatient.patient_id == patient_id)
        .filter(models.FamilyPatient.family_role == "admin")
        .first()
    )


def is_doctor_linked_to_patient(db: Session, doctor_id: int, patient_id: int) -> bool:
    return get_doctor_patient_link(db, doctor_id=doctor_id, patient_id=patient_id) is not None


def is_family_linked_to_patient(db: Session, user_id: int, patient_id: int) -> bool:
    return get_family_patient_link(db, user_id=user_id, patient_id=patient_id) is not None


def can_user_access_patient(db: Session, user: models.User, patient_id: int) -> bool:
    if user.role == "doctor":
        return is_doctor_linked_to_patient(db, doctor_id=user.id, patient_id=patient_id)
    if user.role == "family":
        return is_family_linked_to_patient(db, user_id=user.id, patient_id=patient_id)
    return False


def link_family_to_patient(
    db: Session,
    user_id: int,
    patient_id: int,
    family_role: str = "viewer",
    relation_to_patient: str = "unspecified",
    *,
    commit: bool = True,
):
    family_user = get_user(db, user_id)
    if family_user is None or family_user.role != "family":
        raise RoleConstraintError(
            "Only users with role='family' can be linked in family_patient"
        )

    patient = get_patient(db, patient_id)
    if patient is None:
        raise BusinessRuleError("Patient not found")

    if family_role == "admin":
        existing_admin = get_family_admin_link(db, patient_id)
        if existing_admin is not None and existing_admin.user_id != user_id:
            raise AdminConflictError("An admin already exists for this patient")

    link = models.FamilyPatient(
        user_id=user_id,
        patient_id=patient_id,
        family_role=family_role,
        relation_to_patient=_normalize_text(relation_to_patient),
    )
    db.add(link)
    if commit:
        try:
            db.commit()
            db.refresh(link)
        except IntegrityError:
            db.rollback()
            raise
    else:
        db.flush()
    return link


def transfer_family_admin(db: Session, patient_id: int, new_admin_user_id: int):
    target_link = get_family_patient_link(db, new_admin_user_id, patient_id)
    if target_link is None:
        return None

    current_admin_link = get_family_admin_link(db, patient_id)
    if current_admin_link and current_admin_link.user_id != new_admin_user_id:
        current_admin_link.family_role = "viewer"

    target_link.family_role = "admin"

    try:
        db.commit()
        db.refresh(target_link)
    except IntegrityError:
        db.rollback()
        raise
    return target_link


def update_patient(db: Session, db_patient: models.Patient, payload: schemas.PatientUpdate):
    for field, value in payload.model_dump(exclude_unset=True).items():
        if isinstance(value, str):
            if field == "cin":
                value = _normalize_cin(value)
            else:
                value = value.strip()
        setattr(db_patient, field, value)
    try:
        db.commit()
        db.refresh(db_patient)
    except IntegrityError:
        db.rollback()
        raise
    return db_patient


def delete_patient(db: Session, db_patient: models.Patient):
    db.delete(db_patient)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise


def get_patients_by_doctor(db: Session, doctor_id: int, skip: int = 0, limit: int = 100):
    return (
        db.query(models.Patient)
        .join(models.DoctorPatient, models.DoctorPatient.patient_id == models.Patient.id)
        .filter(models.DoctorPatient.doctor_id == doctor_id)
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_doctors_by_patient(db: Session, patient_id: int, skip: int = 0, limit: int = 100):
    return (
        db.query(models.User)
        .join(models.DoctorPatient, models.DoctorPatient.doctor_id == models.User.id)
        .filter(models.DoctorPatient.patient_id == patient_id)
        .filter(models.User.role == "doctor")
        .offset(skip)
        .limit(limit)
        .all()
    )


def delete_doctor_patient_link(db: Session, doctor_id: int, patient_id: int):
    link = get_doctor_patient_link(db, doctor_id=doctor_id, patient_id=patient_id)
    if link is None:
        return None
    db.delete(link)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise
    return link


def get_patients_by_family_user(db: Session, user_id: int, skip: int = 0, limit: int = 100):
    return (
        db.query(models.Patient)
        .join(models.FamilyPatient, models.FamilyPatient.patient_id == models.Patient.id)
        .filter(models.FamilyPatient.user_id == user_id)
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_family_members_by_patient(db: Session, patient_id: int, skip: int = 0, limit: int = 100):
    return (
        db.query(models.FamilyPatient, models.User)
        .join(models.User, models.User.id == models.FamilyPatient.user_id)
        .filter(models.FamilyPatient.patient_id == patient_id)
        .filter(models.User.role == "family")
        .offset(skip)
        .limit(limit)
        .all()
    )


def update_family_patient_role(
    db: Session,
    link: models.FamilyPatient,
    family_role: str,
):
    link.family_role = family_role
    try:
        db.commit()
        db.refresh(link)
    except IntegrityError:
        db.rollback()
        raise
    return link


def delete_family_patient_link(db: Session, user_id: int, patient_id: int):
    link = get_family_patient_link(db, user_id=user_id, patient_id=patient_id)
    if link is None:
        return None
    db.delete(link)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise
    return link


def get_appointment(db: Session, appointment_id: int):
    return (
        db.query(models.Appointment)
        .filter(models.Appointment.id == appointment_id)
        .first()
    )


def get_appointments(db: Session, skip: int = 0, limit: int = 100):
    return (
        db.query(models.Appointment)
        .order_by(models.Appointment.appointment_date.asc(), models.Appointment.id.asc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def create_appointment(db: Session, payload: schemas.AppointmentCreate):
    appointment_data = payload.model_dump()
    normalized_status = normalize_appointment_status(
        appointment_data.get("status"),
        default=APPOINTMENT_STATUS_SCHEDULED,
    )
    if _should_mark_appointment_as_missed(
        appointment_data["appointment_date"],
        normalized_status,
    ):
        normalized_status = APPOINTMENT_STATUS_MISSED
    appointment_data["status"] = normalized_status

    appointment = models.Appointment(**appointment_data)
    db.add(appointment)
    try:
        db.commit()
        db.refresh(appointment)
    except IntegrityError:
        db.rollback()
        raise
    return appointment


def update_appointment(
    db: Session,
    db_appointment: models.Appointment,
    payload: schemas.AppointmentUpdate,
):
    for field, value in payload.model_dump(exclude_unset=True).items():
        if field == "status":
            value = normalize_appointment_status(
                value,
                default=APPOINTMENT_STATUS_SCHEDULED,
            )
        setattr(db_appointment, field, value)

    _apply_appointment_status_rules(db_appointment)

    try:
        db.commit()
        db.refresh(db_appointment)
    except IntegrityError:
        db.rollback()
        raise
    return db_appointment


def mark_appointment_completed(
    db: Session,
    db_appointment: models.Appointment,
):
    db_appointment.status = APPOINTMENT_STATUS_DONE
    _apply_appointment_status_rules(db_appointment)
    try:
        db.commit()
        db.refresh(db_appointment)
    except IntegrityError:
        db.rollback()
        raise
    return db_appointment


def delete_appointment(db: Session, db_appointment: models.Appointment):
    db.delete(db_appointment)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise


def get_appointments_by_patient(
    db: Session,
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
):
    appointments = (
        db.query(models.Appointment)
        .filter(models.Appointment.patient_id == patient_id)
        .order_by(models.Appointment.appointment_date.asc(), models.Appointment.id.asc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    any_changed = any(_apply_appointment_status_rules(a) for a in appointments)
    if any_changed:
        try:
            db.commit()
        except Exception:
            db.rollback()
    return appointments


def get_appointments_by_doctor(
    db: Session,
    doctor_id: int,
    skip: int = 0,
    limit: int = 100,
):
    appointments = (
        db.query(models.Appointment)
        .filter(models.Appointment.doctor_id == doctor_id)
        .order_by(models.Appointment.appointment_date.asc(), models.Appointment.id.asc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    any_changed = any(_apply_appointment_status_rules(a) for a in appointments)
    if any_changed:
        try:
            db.commit()
        except Exception:
            db.rollback()
    return appointments


def get_prescription(db: Session, prescription_id: int):
    return (
        db.query(models.Prescription)
        .filter(models.Prescription.id == prescription_id)
        .first()
    )


def get_prescriptions(db: Session, skip: int = 0, limit: int = 100):
    return (
        db.query(models.Prescription)
        .order_by(models.Prescription.prescription_date.desc(), models.Prescription.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_prescriptions_by_patient(
    db: Session,
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.Prescription)
        .filter(models.Prescription.patient_id == patient_id)
        .order_by(models.Prescription.prescription_date.desc(), models.Prescription.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_prescriptions_by_doctor(
    db: Session,
    doctor_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.Prescription)
        .filter(models.Prescription.doctor_id == doctor_id)
        .order_by(models.Prescription.prescription_date.desc(), models.Prescription.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_prescriptions_by_family_user(
    db: Session,
    user_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.Prescription)
        .join(models.FamilyPatient, models.FamilyPatient.patient_id == models.Prescription.patient_id)
        .filter(models.FamilyPatient.user_id == user_id)
        .order_by(models.Prescription.prescription_date.desc(), models.Prescription.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def create_prescription(
    db: Session,
    *,
    patient_id: int,
    doctor_id: int,
    prescription_date: date | None,
    notes: str | None,
    status: str = PRESCRIPTION_STATUS_ACTIVE,
):
    prescription = models.Prescription(
        patient_id=patient_id,
        doctor_id=doctor_id,
        prescription_date=prescription_date or date.today(),
        notes=_normalize_text(notes) if notes else None,
        status=normalize_prescription_status(status, default=PRESCRIPTION_STATUS_ACTIVE),
    )
    db.add(prescription)
    try:
        db.commit()
        db.refresh(prescription)
    except IntegrityError:
        db.rollback()
        raise
    return prescription


def update_prescription(
    db: Session,
    db_prescription: models.Prescription,
    payload: schemas.PrescriptionUpdate,
):
    for field, value in payload.model_dump(exclude_unset=True).items():
        if field == "status":
            value = normalize_prescription_status(value, default=PRESCRIPTION_STATUS_ACTIVE)
        elif isinstance(value, str):
            value = _normalize_text(value) if value else None
        setattr(db_prescription, field, value)
    try:
        db.commit()
        db.refresh(db_prescription)
    except IntegrityError:
        db.rollback()
        raise
    return db_prescription


def create_prescription_with_medications(
    db: Session,
    *,
    patient_id: int,
    doctor_id: int,
    prescription_date: date | None,
    notes: str | None,
    status: str,
    medications_data: list[dict],
):
    """Crée une ordonnance et ses médicaments en une seule transaction atomique."""
    prescription = models.Prescription(
        patient_id=patient_id,
        doctor_id=doctor_id,
        prescription_date=prescription_date or date.today(),
        notes=_normalize_text(notes) if notes else None,
        status=normalize_prescription_status(status, default=PRESCRIPTION_STATUS_ACTIVE),
    )
    db.add(prescription)
    db.flush()  # obtient prescription.id sans committer

    medications = []
    for med in medications_data:
        db_med = models.Medication(
            prescription_id=prescription.id,
            patient_id=patient_id,
            doctor_id=doctor_id,
            name=_normalize_text(med["name"]),
            dosage=_normalize_text(med["dosage"]),
            form=_normalize_text(med["form"]) if med.get("form") else None,
            quantity=_normalize_text(med["quantity"]) if med.get("quantity") else None,
            frequency=_normalize_text(med["frequency"]),
            period=_normalize_text(med["period"]) if med.get("period") else None,
            start_date=med["start_date"],
            end_date=med.get("end_date"),
            instructions=_normalize_text(med["instructions"]) if med.get("instructions") else None,
            status=normalize_medication_status(
                med.get("status"), default=MEDICATION_STATUS_ACTIVE
            ),
        )
        db.add(db_med)
        medications.append(db_med)

    try:
        db.commit()
        db.refresh(prescription)
        for db_med in medications:
            db.refresh(db_med)
    except IntegrityError:
        db.rollback()
        raise
    return prescription, medications


def get_medication(db: Session, medication_id: int):
    return db.query(models.Medication).filter(models.Medication.id == medication_id).first()


def get_medications(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Medication).offset(skip).limit(limit).all()


def create_medication(db: Session, payload: schemas.MedicationCreate):
    medication_data = payload.model_dump()
    medication_data["name"] = _normalize_text(medication_data["name"])
    medication_data["dosage"] = _normalize_text(medication_data["dosage"])
    medication_data["frequency"] = _normalize_text(medication_data["frequency"])
    medication_data["form"] = (
        _normalize_text(medication_data["form"])
        if medication_data.get("form")
        else None
    )
    medication_data["quantity"] = (
        _normalize_text(medication_data["quantity"])
        if medication_data.get("quantity")
        else None
    )
    medication_data["period"] = (
        _normalize_text(medication_data["period"])
        if medication_data.get("period")
        else None
    )
    medication_data["instructions"] = (
        _normalize_text(medication_data["instructions"])
        if medication_data.get("instructions")
        else None
    )
    medication_data["status"] = normalize_medication_status(
        medication_data.get("status"),
        default=MEDICATION_STATUS_ACTIVE,
    )

    medication = models.Medication(**medication_data)
    db.add(medication)
    try:
        db.commit()
        db.refresh(medication)
    except IntegrityError:
        db.rollback()
        raise
    return medication


def update_medication(
    db: Session,
    db_medication: models.Medication,
    payload: schemas.MedicationUpdate,
):
    for field, value in payload.model_dump(exclude_unset=True).items():
        if isinstance(value, str):
            value = _normalize_text(value)
        if field == "status":
            value = normalize_medication_status(
                value,
                default=db_medication.status or MEDICATION_STATUS_ACTIVE,
            )
        setattr(db_medication, field, value)
    try:
        db.commit()
        db.refresh(db_medication)
    except IntegrityError:
        db.rollback()
        raise
    return db_medication


def set_medication_status(
    db: Session,
    db_medication: models.Medication,
    *,
    status_value: str,
):
    db_medication.status = normalize_medication_status(status_value)
    try:
        db.commit()
        db.refresh(db_medication)
    except IntegrityError:
        db.rollback()
        raise
    return db_medication


def delete_medication(db: Session, db_medication: models.Medication):
    db.delete(db_medication)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise


def get_medications_by_patient(
    db: Session,
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.Medication)
        .filter(models.Medication.patient_id == patient_id)
        .order_by(models.Medication.start_date.desc(), models.Medication.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_medications_by_patient_status(
    db: Session,
    *,
    patient_id: int,
    status_value: str,
    skip: int = 0,
    limit: int = 100,
):
    normalized_status = normalize_medication_status(status_value)
    return (
        db.query(models.Medication)
        .filter(models.Medication.patient_id == patient_id)
        .filter(models.Medication.status == normalized_status)
        .order_by(models.Medication.start_date.desc(), models.Medication.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_medications_by_doctor(
    db: Session,
    doctor_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.Medication)
        .filter(models.Medication.doctor_id == doctor_id)
        .order_by(models.Medication.start_date.desc(), models.Medication.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_medications_by_family_user(
    db: Session,
    user_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.Medication)
        .join(models.FamilyPatient, models.FamilyPatient.patient_id == models.Medication.patient_id)
        .filter(models.FamilyPatient.user_id == user_id)
        .order_by(models.Medication.start_date.desc(), models.Medication.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_medication_intake(db: Session, intake_id: int):
    return (
        db.query(models.MedicationIntake)
        .filter(models.MedicationIntake.id == intake_id)
        .first()
    )


def get_medication_intakes(db: Session, skip: int = 0, limit: int = 100):
    return (
        db.query(models.MedicationIntake)
        .order_by(models.MedicationIntake.taken_at.desc(), models.MedicationIntake.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_medication_intakes_by_doctor(
    db: Session,
    doctor_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.MedicationIntake)
        .join(
            models.Medication,
            models.Medication.id == models.MedicationIntake.medication_id,
        )
        .filter(models.Medication.doctor_id == doctor_id)
        .order_by(models.MedicationIntake.taken_at.desc(), models.MedicationIntake.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_medication_intakes_by_family_user(
    db: Session,
    user_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.MedicationIntake)
        .join(
            models.Medication,
            models.Medication.id == models.MedicationIntake.medication_id,
        )
        .join(models.FamilyPatient, models.FamilyPatient.patient_id == models.Medication.patient_id)
        .filter(models.FamilyPatient.user_id == user_id)
        .order_by(models.MedicationIntake.taken_at.desc(), models.MedicationIntake.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def create_medication_intake(
    db: Session,
    *,
    payload: schemas.MedicationIntakeCreate,
    validated_by: int,
):
    intake_data = payload.model_dump(exclude_unset=True)
    intake_data["validated_by"] = validated_by
    intake_data["status"] = normalize_intake_status(intake_data["status"])
    intake_data["comment"] = (
        _normalize_text(intake_data["comment"])
        if intake_data.get("comment")
        else None
    )
    intake = models.MedicationIntake(**intake_data)
    db.add(intake)
    try:
        db.commit()
        db.refresh(intake)
    except IntegrityError:
        db.rollback()
        raise
    return intake


def get_intakes_by_medication(
    db: Session,
    medication_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.MedicationIntake)
        .filter(models.MedicationIntake.medication_id == medication_id)
        .order_by(models.MedicationIntake.taken_at.desc(), models.MedicationIntake.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_intakes_by_patient(
    db: Session,
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.MedicationIntake)
        .join(
            models.Medication,
            models.Medication.id == models.MedicationIntake.medication_id,
        )
        .filter(models.Medication.patient_id == patient_id)
        .order_by(models.MedicationIntake.taken_at.desc(), models.MedicationIntake.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def create_patient_allergy(
    db: Session,
    *,
    patient_id: int,
    doctor_id: int,
    payload: schemas.PatientAllergyCreate,
):
    allergy = models.PatientAllergy(
        patient_id=patient_id,
        doctor_id=doctor_id,
        allergen=_normalize_text(payload.allergen),
        reaction=_normalize_text(payload.reaction) if payload.reaction else None,
        severity=payload.severity,
        notes=_normalize_text(payload.notes) if payload.notes else None,
    )
    db.add(allergy)
    try:
        db.commit()
        db.refresh(allergy)
    except IntegrityError:
        db.rollback()
        raise
    return allergy


def get_patient_allergies(
    db: Session,
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.PatientAllergy)
        .filter(models.PatientAllergy.patient_id == patient_id)
        .order_by(models.PatientAllergy.created_at.desc(), models.PatientAllergy.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_patient_location(db: Session, location_id: int):
    return (
        db.query(models.PatientLocation)
        .filter(models.PatientLocation.id == location_id)
        .first()
    )


def create_patient_location(db: Session, payload: schemas.PatientLocationCreate):
    location_data = payload.model_dump(exclude_unset=True)
    location = models.PatientLocation(**location_data)
    db.add(location)
    try:
        db.commit()
        db.refresh(location)
    except IntegrityError:
        db.rollback()
        raise
    return location


def get_locations_by_patient(
    db: Session,
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.PatientLocation)
        .filter(models.PatientLocation.patient_id == patient_id)
        .order_by(models.PatientLocation.recorded_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_last_location_for_patient(db: Session, patient_id: int):
    return (
        db.query(models.PatientLocation)
        .filter(models.PatientLocation.patient_id == patient_id)
        .order_by(models.PatientLocation.recorded_at.desc())
        .first()
    )


def get_questionnaire(db: Session, questionnaire_id: int):
    return (
        db.query(models.Questionnaire)
        .filter(models.Questionnaire.id == questionnaire_id)
        .first()
    )


def get_questionnaires(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Questionnaire).offset(skip).limit(limit).all()


def create_questionnaire(db: Session, payload: schemas.QuestionnaireCreate):
    questionnaire = models.Questionnaire(**payload.model_dump())
    db.add(questionnaire)
    try:
        db.commit()
        db.refresh(questionnaire)
    except IntegrityError:
        db.rollback()
        raise
    return questionnaire


def update_questionnaire(
    db: Session,
    db_questionnaire: models.Questionnaire,
    payload: schemas.QuestionnaireUpdate,
):
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(db_questionnaire, field, value)
    try:
        db.commit()
        db.refresh(db_questionnaire)
    except IntegrityError:
        db.rollback()
        raise
    return db_questionnaire


def delete_questionnaire(db: Session, db_questionnaire: models.Questionnaire):
    db.delete(db_questionnaire)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise


def get_questionnaires_by_patient(
    db: Session,
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.Questionnaire)
        .filter(models.Questionnaire.patient_id == patient_id)
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_diagnosis(db: Session, diagnosis_id: int):
    return db.query(models.Diagnosis).filter(models.Diagnosis.id == diagnosis_id).first()


def get_diagnoses(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Diagnosis).offset(skip).limit(limit).all()


def create_diagnosis(db: Session, payload: schemas.DiagnosisCreate):
    diagnosis = models.Diagnosis(**payload.model_dump())
    db.add(diagnosis)
    try:
        db.commit()
        db.refresh(diagnosis)
    except IntegrityError:
        db.rollback()
        raise
    return diagnosis


def update_diagnosis(
    db: Session,
    db_diagnosis: models.Diagnosis,
    payload: schemas.DiagnosisUpdate,
):
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(db_diagnosis, field, value)
    try:
        db.commit()
        db.refresh(db_diagnosis)
    except IntegrityError:
        db.rollback()
        raise
    return db_diagnosis


def delete_diagnosis(db: Session, db_diagnosis: models.Diagnosis):
    db.delete(db_diagnosis)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise


def get_diagnoses_by_patient(
    db: Session,
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.Diagnosis)
        .filter(models.Diagnosis.patient_id == patient_id)
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_alert(db: Session, alert_id: int):
    return db.query(models.Alert).filter(models.Alert.id == alert_id).first()


def get_alerts(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Alert).offset(skip).limit(limit).all()


def create_alert(db: Session, payload: schemas.AlertCreate):
    alert = models.Alert(**payload.model_dump())
    db.add(alert)
    try:
        db.commit()
        db.refresh(alert)
    except IntegrityError:
        db.rollback()
        raise
    return alert


def update_alert(
    db: Session,
    db_alert: models.Alert,
    payload: schemas.AlertUpdate,
):
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(db_alert, field, value)
    try:
        db.commit()
        db.refresh(db_alert)
    except IntegrityError:
        db.rollback()
        raise
    return db_alert


def mark_alert_as_read(db: Session, db_alert: models.Alert):
    db_alert.is_read = True
    try:
        db.commit()
        db.refresh(db_alert)
    except IntegrityError:
        db.rollback()
        raise
    return db_alert


def delete_alert(db: Session, db_alert: models.Alert):
    db.delete(db_alert)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise


def get_alerts_by_patient(
    db: Session,
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.Alert)
        .filter(models.Alert.patient_id == patient_id)
        .offset(skip)
        .limit(limit)
        .all()
    )


def get_medical_note(db: Session, note_id: int):
    return db.query(models.MedicalNote).filter(models.MedicalNote.id == note_id).first()


def get_medical_notes(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.MedicalNote).offset(skip).limit(limit).all()


def create_medical_note(db: Session, payload: schemas.MedicalNoteCreate):
    note = models.MedicalNote(**payload.model_dump())
    db.add(note)
    try:
        db.commit()
        db.refresh(note)
    except IntegrityError:
        db.rollback()
        raise
    return note


def update_medical_note(
    db: Session,
    db_note: models.MedicalNote,
    payload: schemas.MedicalNoteUpdate,
):
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(db_note, field, value)
    try:
        db.commit()
        db.refresh(db_note)
    except IntegrityError:
        db.rollback()
        raise
    return db_note


def delete_medical_note(db: Session, db_note: models.MedicalNote):
    db.delete(db_note)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise


def get_medical_notes_by_patient(
    db: Session,
    patient_id: int,
    skip: int = 0,
    limit: int = 100,
):
    return (
        db.query(models.MedicalNote)
        .filter(models.MedicalNote.patient_id == patient_id)
        .offset(skip)
        .limit(limit)
        .all()
    )
