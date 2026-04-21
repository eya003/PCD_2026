from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    Time,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

from .database import Base


class Patient(Base):
    __tablename__ = "patients"

    id = Column(Integer, primary_key=True)
    patient_code = Column(String(50), unique=True, index=True, nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    birth_date = Column(Date, nullable=False)
    cin = Column(String(20), unique=True, index=True, nullable=True)
    created_at = Column(
        DateTime,
        nullable=True,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    doctor_links = relationship("DoctorPatient", back_populates="patient")
    family_links = relationship("FamilyPatient", back_populates="patient")
    appointments = relationship("Appointment", back_populates="patient")
    prescriptions = relationship("Prescription", back_populates="patient")
    medications = relationship("Medication", back_populates="patient")
    medication_schedule_template = relationship(
        "MedicationScheduleTemplate",
        back_populates="patient",
        uselist=False,
    )
    scheduled_medication_doses = relationship(
        "ScheduledMedicationDose",
        back_populates="patient",
    )
    dose_notifications = relationship("DoseNotification", back_populates="patient")
    allergies = relationship("PatientAllergy", back_populates="patient")
    locations = relationship("PatientLocation", back_populates="patient")
    safe_zone = relationship(
        "PatientSafeZone",
        back_populates="patient",
        uselist=False,
    )
    questionnaires = relationship("Questionnaire", back_populates="patient")
    diagnoses = relationship("Diagnosis", back_populates="patient")
    alerts = relationship("Alert", back_populates="patient")
    medical_notes = relationship("MedicalNote", back_populates="patient")


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "role IN ('doctor', 'family')",
            name="users_role_check",
        ),
    )

    id = Column(Integer, primary_key=True)
    cin = Column(String(20), unique=True, index=True, nullable=True)
    email = Column(String(150), unique=True, index=True, nullable=False)
    first_name = Column(String(100), nullable=True)
    last_name = Column(String(100), nullable=True)
    role = Column(String(30), nullable=False)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(
        DateTime,
        nullable=True,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    doctor_patient_links = relationship("DoctorPatient", back_populates="doctor")
    family_patient_links = relationship("FamilyPatient", back_populates="user")
    appointments = relationship(
        "Appointment",
        back_populates="doctor",
        foreign_keys="Appointment.doctor_id",
    )
    prescriptions = relationship(
        "Prescription",
        back_populates="doctor",
        foreign_keys="Prescription.doctor_id",
    )
    medications = relationship(
        "Medication",
        back_populates="doctor",
        foreign_keys="Medication.doctor_id",
    )
    validated_intakes = relationship(
        "MedicationIntake",
        back_populates="validator",
        foreign_keys="MedicationIntake.validated_by",
    )
    validated_scheduled_doses = relationship(
        "ScheduledMedicationDose",
        back_populates="validator",
        foreign_keys="ScheduledMedicationDose.validated_by",
    )
    created_medication_schedule_templates = relationship(
        "MedicationScheduleTemplate",
        back_populates="created_by_user",
        foreign_keys="MedicationScheduleTemplate.created_by",
    )
    received_dose_notifications = relationship(
        "DoseNotification",
        back_populates="recipient_user",
        foreign_keys="DoseNotification.recipient_user_id",
    )
    safe_zones_updated = relationship(
        "PatientSafeZone",
        back_populates="updated_by_user",
        foreign_keys="PatientSafeZone.updated_by",
    )
    questionnaires_filled = relationship(
        "Questionnaire",
        back_populates="filled_by_user",
        foreign_keys="Questionnaire.filled_by",
    )
    diagnoses_authored = relationship(
        "Diagnosis",
        back_populates="doctor",
        foreign_keys="Diagnosis.doctor_id",
    )
    allergies_noted = relationship(
        "PatientAllergy",
        back_populates="doctor",
        foreign_keys="PatientAllergy.doctor_id",
    )
    medical_notes_authored = relationship(
        "MedicalNote",
        back_populates="doctor",
        foreign_keys="MedicalNote.doctor_id",
    )


class DoctorPatient(Base):
    __tablename__ = "doctor_patient"

    doctor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )

    doctor = relationship("User", back_populates="doctor_patient_links")
    patient = relationship("Patient", back_populates="doctor_links")


class FamilyPatient(Base):
    __tablename__ = "family_patient"
    __table_args__ = (
        Index(
            "family_one_admin_per_patient",
            "patient_id",
            unique=True,
            postgresql_where=text("family_role = 'admin'"),
        ),
        Index("family_patient_patient_idx", "patient_id"),
        Index("family_patient_user_idx", "user_id"),
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    family_role = Column(
        String(6),
        nullable=False,
        server_default=text("'viewer'"),
    )
    relation_to_patient = Column(String(30), nullable=True)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("now()"),
    )

    user = relationship("User", back_populates="family_patient_links")
    patient = relationship("Patient", back_populates="family_links")


class Appointment(Base):
    __tablename__ = "appointments"
    __table_args__ = (
        CheckConstraint(
            "status IN ('scheduled', 'done', 'cancelled', 'missed')",
            name="appointments_status_check",
        ),
        Index("appointments_doctor_idx", "doctor_id"),
        Index("appointments_patient_idx", "patient_id"),
    )

    id = Column(Integer, primary_key=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
    )
    doctor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    appointment_date = Column(DateTime, nullable=False)
    notes = Column(Text, nullable=True)
    status = Column(
        String(20),
        nullable=False,
        server_default=text("'scheduled'"),
    )
    created_at = Column(
        DateTime,
        nullable=True,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    patient = relationship("Patient", back_populates="appointments")
    doctor = relationship("User", back_populates="appointments")


class Prescription(Base):
    __tablename__ = "prescriptions"
    __table_args__ = (
        CheckConstraint(
            "status IN ('active', 'completed', 'cancelled')",
            name="prescriptions_status_check",
        ),
        Index("prescriptions_date_idx", "prescription_date"),
        Index("prescriptions_doctor_idx", "doctor_id"),
        Index("prescriptions_patient_idx", "patient_id"),
    )

    id = Column(Integer, primary_key=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
    )
    doctor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    prescription_date = Column(
        Date,
        nullable=False,
        server_default=text("CURRENT_DATE"),
    )
    notes = Column(Text, nullable=True)
    status = Column(
        String(20),
        nullable=False,
        server_default=text("'active'"),
    )
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    patient = relationship("Patient", back_populates="prescriptions")
    doctor = relationship("User", back_populates="prescriptions")
    medications = relationship("Medication", back_populates="prescription")
    scheduled_doses = relationship("ScheduledMedicationDose", back_populates="prescription")


class Medication(Base):
    __tablename__ = "medications"
    __table_args__ = (
        CheckConstraint(
            "status IN ('active', 'completed', 'stopped')",
            name="medications_status_check",
        ),
        CheckConstraint(
            "schedule_mode IN ('fixed_times', 'default_times', 'distributed')",
            name="medications_schedule_mode_check",
        ),
        CheckConstraint(
            "intake_count_per_day IS NULL OR intake_count_per_day > 0",
            name="medications_intake_count_per_day_check",
        ),
        CheckConstraint(
            "duration_days IS NULL OR duration_days > 0",
            name="medications_duration_days_check",
        ),
        Index("medications_doctor_idx", "doctor_id"),
        Index("medications_intake_count_per_day_idx", "intake_count_per_day"),
        Index("medications_is_as_needed_idx", "is_as_needed"),
        Index("medications_patient_idx", "patient_id"),
        Index("medications_prescription_idx", "prescription_id"),
        Index("medications_status_idx", "status"),
    )

    id = Column(Integer, primary_key=True)
    prescription_id = Column(
        Integer,
        ForeignKey("prescriptions.id", ondelete="SET NULL"),
        nullable=True,
    )
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=True,
    )
    doctor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    name = Column(String(150), nullable=False)
    dosage = Column(String(100), nullable=True)
    form = Column(String(50), nullable=True)
    quantity = Column(String(100), nullable=True)
    frequency = Column(String(100), nullable=True)
    period = Column(String(100), nullable=True)
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)
    instructions = Column(Text, nullable=True)
    prescribed_at = Column(
        DateTime,
        nullable=True,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    status = Column(
        String(20),
        nullable=False,
        server_default=text("'active'"),
    )
    intake_count_per_day = Column(Integer, nullable=True)
    duration_days = Column(Integer, nullable=True)
    schedule_mode = Column(
        String(30),
        nullable=True,
        server_default=text("'default_times'"),
    )
    day_start_time = Column(Time, nullable=True)
    day_end_time = Column(Time, nullable=True)
    specific_times = Column(JSONB, nullable=True)
    allow_family_adjustment = Column(
        Boolean,
        nullable=False,
        server_default=text("true"),
    )
    is_as_needed = Column(
        Boolean,
        nullable=False,
        server_default=text("false"),
    )
    created_at = Column(
        DateTime,
        nullable=True,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    prescription = relationship("Prescription", back_populates="medications")
    patient = relationship("Patient", back_populates="medications")
    doctor = relationship("User", back_populates="medications")
    intakes = relationship(
        "MedicationIntake",
        back_populates="medication",
        foreign_keys="MedicationIntake.medication_id",
    )
    scheduled_doses = relationship(
        "ScheduledMedicationDose",
        back_populates="medication",
        foreign_keys="ScheduledMedicationDose.medication_id",
    )


class MedicationScheduleTemplate(Base):
    __tablename__ = "medication_schedule_templates"
    __table_args__ = (
        CheckConstraint(
            "day_end_time > day_start_time",
            name="medication_schedule_templates_day_range_check",
        ),
        CheckConstraint(
            "reminder_offset_minutes >= 0 AND reminder_offset_minutes <= 1440",
            name="medication_schedule_templates_reminder_check",
        ),
        Index(
            "medication_schedule_templates_patient_active_uidx",
            "patient_id",
            unique=True,
            postgresql_where=text("is_active = true"),
        ),
        Index("medication_schedule_templates_patient_idx", "patient_id"),
    )

    id = Column(Integer, primary_key=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
    )
    created_by = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    morning_time = Column(
        Time,
        nullable=False,
        server_default=text("'08:00:00'"),
    )
    noon_time = Column(
        Time,
        nullable=False,
        server_default=text("'13:00:00'"),
    )
    evening_time = Column(
        Time,
        nullable=False,
        server_default=text("'20:00:00'"),
    )
    day_start_time = Column(
        Time,
        nullable=False,
        server_default=text("'08:00:00'"),
    )
    day_end_time = Column(
        Time,
        nullable=False,
        server_default=text("'23:00:00'"),
    )
    reminder_offset_minutes = Column(
        Integer,
        nullable=False,
        server_default=text("10"),
    )
    allow_family_adjustment = Column(
        Boolean,
        nullable=False,
        server_default=text("true"),
    )
    is_active = Column(
        Boolean,
        nullable=False,
        server_default=text("true"),
    )
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    updated_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    patient = relationship("Patient", back_populates="medication_schedule_template")
    created_by_user = relationship(
        "User",
        back_populates="created_medication_schedule_templates",
        foreign_keys=[created_by],
    )


class ScheduledMedicationDose(Base):
    __tablename__ = "scheduled_medication_doses"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'taken', 'missed', 'skipped', 'rescheduled', 'cancelled')",
            name="scheduled_medication_doses_status_check",
        ),
        CheckConstraint(
            "validation_method IN ('manual', 'auto', 'system')",
            name="scheduled_medication_doses_validation_method_check",
        ),
        Index("scheduled_medication_doses_medication_idx", "medication_id"),
        Index("scheduled_medication_doses_patient_date_idx", "patient_id", "scheduled_date"),
        Index("scheduled_medication_doses_patient_idx", "patient_id"),
        Index("scheduled_medication_doses_prescription_idx", "prescription_id"),
        Index("scheduled_medication_doses_scheduled_for_idx", "scheduled_for"),
        Index("scheduled_medication_doses_status_idx", "status"),
        Index(
            "scheduled_medication_doses_unique_slot_uidx",
            "medication_id",
            "scheduled_for",
            unique=True,
        ),
    )

    id = Column(BigInteger, primary_key=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
    )
    medication_id = Column(
        Integer,
        ForeignKey("medications.id", ondelete="CASCADE"),
        nullable=False,
    )
    prescription_id = Column(
        Integer,
        ForeignKey("prescriptions.id", ondelete="SET NULL"),
        nullable=True,
    )
    scheduled_date = Column(Date, nullable=False)
    scheduled_time = Column(Time, nullable=False)
    scheduled_for = Column(DateTime, nullable=False)
    period_label = Column(String(30), nullable=True)
    status = Column(
        String(20),
        nullable=False,
        server_default=text("'pending'"),
    )
    original_scheduled_for = Column(DateTime, nullable=True)
    rescheduled_for = Column(DateTime, nullable=True)
    taken_at = Column(DateTime, nullable=True)
    validated_by = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    validation_method = Column(
        String(20),
        nullable=True,
        server_default=text("'manual'"),
    )
    skipped_reason = Column(Text, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    updated_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    patient = relationship("Patient", back_populates="scheduled_medication_doses")
    medication = relationship("Medication", back_populates="scheduled_doses")
    prescription = relationship("Prescription", back_populates="scheduled_doses")
    validator = relationship(
        "User",
        back_populates="validated_scheduled_doses",
        foreign_keys=[validated_by],
    )
    intakes = relationship(
        "MedicationIntake",
        back_populates="scheduled_dose",
        foreign_keys="MedicationIntake.scheduled_dose_id",
    )
    notifications = relationship("DoseNotification", back_populates="scheduled_dose")


class MedicationIntake(Base):
    __tablename__ = "medication_intakes"
    __table_args__ = (
        CheckConstraint(
            "status IN ('taken', 'missed', 'skipped', 'rescheduled')",
            name="medication_intakes_status_check",
        ),
        Index("medication_intakes_medication_idx", "medication_id"),
        Index("medication_intakes_scheduled_dose_idx", "scheduled_dose_id"),
    )

    id = Column(Integer, primary_key=True)
    medication_id = Column(
        Integer,
        ForeignKey("medications.id", ondelete="CASCADE"),
        nullable=True,
    )
    validated_by = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    taken_at = Column(
        DateTime,
        nullable=True,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    status = Column(String(20), nullable=True)
    comment = Column(Text, nullable=True)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    scheduled_for = Column(DateTime, nullable=True)
    scheduled_dose_id = Column(
        BigInteger,
        ForeignKey("scheduled_medication_doses.id", ondelete="SET NULL"),
        nullable=True,
    )

    medication = relationship(
        "Medication",
        back_populates="intakes",
        foreign_keys=[medication_id],
    )
    validator = relationship(
        "User",
        back_populates="validated_intakes",
        foreign_keys=[validated_by],
    )
    scheduled_dose = relationship(
        "ScheduledMedicationDose",
        back_populates="intakes",
        foreign_keys=[scheduled_dose_id],
    )


class DoseNotification(Base):
    __tablename__ = "dose_notifications"
    __table_args__ = (
        CheckConstraint(
            "channel IN ('local', 'push')",
            name="dose_notifications_channel_check",
        ),
        CheckConstraint(
            "status IN ('pending', 'sent', 'failed', 'cancelled')",
            name="dose_notifications_status_check",
        ),
        Index("dose_notifications_patient_idx", "patient_id"),
        Index("dose_notifications_scheduled_dose_idx", "scheduled_dose_id"),
        Index("dose_notifications_send_at_idx", "send_at"),
        Index("dose_notifications_status_idx", "status"),
    )

    id = Column(BigInteger, primary_key=True)
    scheduled_dose_id = Column(
        BigInteger,
        ForeignKey("scheduled_medication_doses.id", ondelete="CASCADE"),
        nullable=False,
    )
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
    )
    recipient_user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    channel = Column(
        String(20),
        nullable=False,
        server_default=text("'local'"),
    )
    send_at = Column(DateTime, nullable=False)
    sent_at = Column(DateTime, nullable=True)
    status = Column(
        String(20),
        nullable=False,
        server_default=text("'pending'"),
    )
    error_message = Column(Text, nullable=True)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    scheduled_dose = relationship("ScheduledMedicationDose", back_populates="notifications")
    patient = relationship("Patient", back_populates="dose_notifications")
    recipient_user = relationship(
        "User",
        back_populates="received_dose_notifications",
        foreign_keys=[recipient_user_id],
    )


class PatientAllergy(Base):
    __tablename__ = "patient_allergies"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    doctor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    allergen = Column(String(255), nullable=False)
    reaction = Column(Text, nullable=True)
    severity = Column(
        String(20),
        nullable=False,
        server_default=text("'moderate'"),
    )
    notes = Column(Text, nullable=True)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    patient = relationship("Patient", back_populates="allergies")
    doctor = relationship(
        "User",
        back_populates="allergies_noted",
        foreign_keys=[doctor_id],
    )


class PatientLocation(Base):
    __tablename__ = "patient_locations"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    recorded_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    patient = relationship("Patient", back_populates="locations")


class PatientSafeZone(Base):
    __tablename__ = "patient_safe_zones"

    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )
    origin_latitude = Column(Float, nullable=False)
    origin_longitude = Column(Float, nullable=False)
    radius_meters = Column(Float, nullable=False)
    updated_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    updated_by = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    patient = relationship("Patient", back_populates="safe_zone")
    updated_by_user = relationship(
        "User",
        back_populates="safe_zones_updated",
        foreign_keys=[updated_by],
    )


class Questionnaire(Base):
    __tablename__ = "questionnaires"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    filled_by = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    score = Column(Integer, nullable=False)
    answers = Column(JSONB, nullable=False)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    patient = relationship("Patient", back_populates="questionnaires")
    filled_by_user = relationship(
        "User",
        back_populates="questionnaires_filled",
        foreign_keys=[filled_by],
    )
    diagnoses = relationship("Diagnosis", back_populates="questionnaire")


class Diagnosis(Base):
    __tablename__ = "diagnoses"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    doctor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    questionnaire_id = Column(
        Integer,
        ForeignKey("questionnaires.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    model_result = Column(Text, nullable=False)
    confidence_score = Column(Float, nullable=True)
    questionnaire_score = Column(Integer, nullable=True)
    final_medical_opinion = Column(Text, nullable=True)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    patient = relationship("Patient", back_populates="diagnoses")
    doctor = relationship(
        "User",
        back_populates="diagnoses_authored",
        foreign_keys=[doctor_id],
    )
    questionnaire = relationship("Questionnaire", back_populates="diagnoses")


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    type = Column(String(100), nullable=False)
    message = Column(Text, nullable=False)
    is_read = Column(Boolean, nullable=False, server_default=text("FALSE"))
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    patient = relationship("Patient", back_populates="alerts")


class MedicalNote(Base):
    __tablename__ = "medical_notes"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    doctor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    note = Column(Text, nullable=False)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )

    patient = relationship("Patient", back_populates="medical_notes")
    doctor = relationship(
        "User",
        back_populates="medical_notes_authored",
        foreign_keys=[doctor_id],
    )
