from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB

from .database import Base


class Patient(Base):
    __tablename__ = "patients"

    id = Column(Integer, primary_key=True, index=True)
    patient_code = Column(String(50), unique=True, index=True, nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    birth_date = Column(Date, nullable=False)
    cin = Column(String(50), unique=True, index=True, nullable=False)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    cin = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    role = Column(String(20), nullable=False)
    password_hash = Column(String(512), nullable=False)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
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


class FamilyPatient(Base):
    __tablename__ = "family_patient"

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
    family_role = Column(String(20), nullable=False, default="viewer")
    relation_to_patient = Column(String(100), nullable=False)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )


class Appointment(Base):
    __tablename__ = "appointments"
    __table_args__ = (
        CheckConstraint(
            "status IN ('scheduled', 'done', 'cancelled', 'missed')",
            name="appointments_status_check",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    doctor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    appointment_date = Column(DateTime, nullable=False)
    notes = Column(Text, nullable=True)
    status = Column(String(20), nullable=False)
    created_at = Column(
        DateTime,
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP"),
    )


class Prescription(Base):
    __tablename__ = "prescriptions"

    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    doctor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
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


class Medication(Base):
    __tablename__ = "medications"

    id = Column(Integer, primary_key=True, index=True)
    prescription_id = Column(
        Integer,
        ForeignKey("prescriptions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    patient_id = Column(
        Integer,
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    doctor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name = Column(String(255), nullable=False)
    dosage = Column(String(255), nullable=False)
    form = Column(String(100), nullable=True)
    quantity = Column(String(100), nullable=True)
    frequency = Column(String(255), nullable=False)
    period = Column(String(255), nullable=True)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)
    instructions = Column(Text, nullable=True)
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


class MedicationIntake(Base):
    __tablename__ = "medication_intakes"

    id = Column(Integer, primary_key=True, index=True)
    medication_id = Column(
        Integer,
        ForeignKey("medications.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    validated_by = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    taken_at = Column(DateTime, nullable=False)
    status = Column(String(50), nullable=False)
    comment = Column(Text, nullable=True)


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
