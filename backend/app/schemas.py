from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class PatientBase(BaseModel):
    patient_code: str = Field(min_length=1, max_length=50)
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    birth_date: date
    cin: str = Field(min_length=3, max_length=50)


class PatientCreate(PatientBase):
    pass


class Patient(PatientBase):
    id: int
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class PatientUpdate(BaseModel):
    patient_code: str | None = Field(default=None, min_length=1, max_length=50)
    first_name: str | None = Field(default=None, min_length=1, max_length=100)
    last_name: str | None = Field(default=None, min_length=1, max_length=100)
    birth_date: date | None = None
    cin: str | None = Field(default=None, min_length=3, max_length=50)
    model_config = ConfigDict(extra="forbid")


UserRole = Literal["doctor", "family"]
FamilyAccessRole = Literal["admin", "viewer"]
AppointmentStatus = Literal["scheduled", "done", "cancelled", "missed"]
PrescriptionStatus = Literal["active", "completed", "cancelled"]
MedicationStatus = Literal["active", "completed", "cancelled"]
MedicationIntakeStatus = Literal["taken", "missed"]
AllergySeverity = str  # Changed from Literal to str to prevent 500 validation errors on legacy data


class UserBase(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    cin: str = Field(min_length=3, max_length=50)
    email: str = Field(min_length=3, max_length=255)
    role: UserRole


class UserCreate(UserBase):
    password: str = Field(min_length=6, max_length=128)


class User(UserBase):
    id: int
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class LoginRequest(BaseModel):
    cin: str
    password: str


class RegisterDoctorRequest(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    cin: str = Field(min_length=3, max_length=50)
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=6, max_length=128)


class RegisterFamilyRequest(RegisterDoctorRequest):
    patient_cin: str = Field(min_length=3, max_length=50)
    family_role: FamilyAccessRole
    relation_to_patient: str = Field(min_length=1, max_length=100)


class RegisterLegacyRequest(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    cin: str = Field(min_length=3, max_length=50)
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=6, max_length=128)
    role: UserRole
    patient_cin: str | None = Field(default=None, min_length=3, max_length=50)
    family_role: FamilyAccessRole | None = None
    relation_to_patient: str | None = Field(default=None, min_length=1, max_length=100)


class TokenUser(BaseModel):
    id: int
    first_name: str
    last_name: str
    cin: str
    email: str
    role: UserRole
    model_config = ConfigDict(from_attributes=True)


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: UserRole
    user_id: int
    user: TokenUser


class DoctorPatientLinkCreate(BaseModel):
    doctor_id: int
    patient_id: int


class DoctorPatientLink(BaseModel):
    doctor_id: int
    patient_id: int
    model_config = ConfigDict(from_attributes=True)


class FamilyPatientLinkCreate(BaseModel):
    user_id: int
    patient_id: int
    family_role: FamilyAccessRole = "viewer"
    relation_to_patient: str = Field(default="unspecified", min_length=1, max_length=100)


class FamilyPatientLink(BaseModel):
    user_id: int
    patient_id: int
    family_role: FamilyAccessRole
    relation_to_patient: str
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class TransferFamilyAdminRequest(BaseModel):
    patient_id: int
    new_admin_user_id: int


class FamilyPatientRoleUpdate(BaseModel):
    family_role: FamilyAccessRole


class FamilyPatientMember(BaseModel):
    user_id: int
    patient_id: int
    family_role: FamilyAccessRole
    relation_to_patient: str
    first_name: str
    last_name: str
    cin: str
    email: str


class AppointmentBase(BaseModel):
    patient_id: int = Field(gt=0)
    doctor_id: int = Field(gt=0)
    appointment_date: datetime
    notes: str | None = Field(default=None, max_length=5000)
    status: AppointmentStatus = "scheduled"


class AppointmentCreate(AppointmentBase):
    pass


class AppointmentUpdate(BaseModel):
    patient_id: int | None = Field(default=None, gt=0)
    doctor_id: int | None = Field(default=None, gt=0)
    appointment_date: datetime | None = None
    notes: str | None = Field(default=None, max_length=5000)
    status: AppointmentStatus | None = None
    model_config = ConfigDict(extra="forbid")


class Appointment(AppointmentBase):
    id: int
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class PrescriptionCreate(BaseModel):
    patient_id: int = Field(gt=0)
    prescription_date: date | None = None
    notes: str | None = Field(default=None, max_length=5000)
    status: PrescriptionStatus = "active"


class PrescriptionUpdate(BaseModel):
    prescription_date: date | None = None
    notes: str | None = Field(default=None, max_length=5000)
    status: PrescriptionStatus | None = None
    model_config = ConfigDict(extra="forbid")


class Prescription(BaseModel):
    id: int
    patient_id: int
    doctor_id: int
    prescription_date: date
    notes: str | None = None
    status: PrescriptionStatus
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class MedicationCreateItem(BaseModel):
    """Single medication line inside a with-items payload (no patient_id/doctor_id)."""

    name: str = Field(min_length=1, max_length=255)
    dosage: str = Field(min_length=1, max_length=255)
    form: str | None = Field(default=None, min_length=1, max_length=100)
    quantity: str | None = Field(default=None, min_length=1, max_length=100)
    frequency: str = Field(min_length=1, max_length=255)
    period: str | None = Field(default=None, min_length=1, max_length=255)
    start_date: date
    end_date: date | None = None
    instructions: str | None = Field(default=None, max_length=5000)
    status: MedicationStatus = "active"

    @model_validator(mode="after")
    def validate_date_range(self):
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        return self


class PrescriptionWithItemsCreate(BaseModel):
    """Atomic payload: ordonnance + liste de médicaments en une seule requête."""

    patient_id: int = Field(gt=0)
    prescription_date: date | None = None
    notes: str | None = Field(default=None, max_length=5000)
    status: PrescriptionStatus = "active"
    medications: list[MedicationCreateItem] = Field(min_length=1)


class PrescriptionWithItemsResponse(BaseModel):
    prescription: "Prescription"
    medications: list["Medication"]
    model_config = ConfigDict(from_attributes=True)


class MedicationBase(BaseModel):
    prescription_id: int | None = Field(default=None, gt=0)
    patient_id: int = Field(gt=0)
    doctor_id: int | None = Field(default=None, gt=0)
    name: str = Field(min_length=1, max_length=255)
    dosage: str = Field(min_length=1, max_length=255)
    form: str | None = Field(default=None, min_length=1, max_length=100)
    quantity: str | None = Field(default=None, min_length=1, max_length=100)
    frequency: str = Field(min_length=1, max_length=255)
    period: str | None = Field(default=None, min_length=1, max_length=255)
    start_date: date
    end_date: date | None = None
    instructions: str | None = Field(default=None, max_length=5000)
    status: MedicationStatus = "active"

    @model_validator(mode="after")
    def validate_date_range(self):
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        return self


class MedicationCreate(MedicationBase):
    pass


class MedicationUpdate(BaseModel):
    prescription_id: int | None = Field(default=None, gt=0)
    patient_id: int | None = Field(default=None, gt=0)
    doctor_id: int | None = Field(default=None, gt=0)
    name: str | None = Field(default=None, min_length=1, max_length=255)
    dosage: str | None = Field(default=None, min_length=1, max_length=255)
    form: str | None = Field(default=None, min_length=1, max_length=100)
    quantity: str | None = Field(default=None, min_length=1, max_length=100)
    frequency: str | None = Field(default=None, min_length=1, max_length=255)
    period: str | None = Field(default=None, min_length=1, max_length=255)
    start_date: date | None = None
    end_date: date | None = None
    instructions: str | None = Field(default=None, max_length=5000)
    status: MedicationStatus | None = None
    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="after")
    def validate_date_range(self):
        if (
            self.start_date is not None
            and self.end_date is not None
            and self.end_date < self.start_date
        ):
            raise ValueError("end_date must be on or after start_date")
        return self


class Medication(MedicationBase):
    id: int
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class MedicationSummary(BaseModel):
    id: int
    prescription_id: int | None = None
    patient_id: int
    doctor_id: int
    name: str
    dosage: str
    form: str | None = None
    quantity: str | None = None
    frequency: str
    period: str | None = None
    start_date: date
    end_date: date | None = None
    instructions: str | None = None
    status: MedicationStatus
    model_config = ConfigDict(from_attributes=True)


class MedicationIntakeBase(BaseModel):
    medication_id: int = Field(gt=0)
    taken_at: datetime = Field(default_factory=datetime.utcnow)
    status: MedicationIntakeStatus
    comment: str | None = Field(default=None, max_length=5000)


class MedicationIntakeCreate(MedicationIntakeBase):
    pass


class MedicationIntake(MedicationIntakeBase):
    id: int
    validated_by: int | None = None
    model_config = ConfigDict(from_attributes=True)


class PatientAllergyCreate(BaseModel):
    allergen: str = Field(min_length=1, max_length=255)
    reaction: str | None = Field(default=None, max_length=5000)
    severity: AllergySeverity = "moderate"
    notes: str | None = Field(default=None, max_length=5000)


class PatientAllergy(BaseModel):
    id: int
    patient_id: int
    doctor_id: int | None = None
    allergen: str
    reaction: str | None = None
    severity: AllergySeverity
    notes: str | None = None
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class PatientLocationCreate(BaseModel):
    patient_id: int = Field(gt=0)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    recorded_at: datetime | None = None


class PatientLocation(BaseModel):
    id: int
    patient_id: int
    latitude: float
    longitude: float
    recorded_at: datetime
    model_config = ConfigDict(from_attributes=True)


class QuestionnaireBase(BaseModel):
    patient_id: int = Field(gt=0)
    filled_by: int | None = Field(default=None, gt=0)
    score: int = Field(ge=0)
    answers: dict[str, Any]


class QuestionnaireCreate(QuestionnaireBase):
    pass


class QuestionnaireUpdate(BaseModel):
    patient_id: int | None = Field(default=None, gt=0)
    filled_by: int | None = Field(default=None, gt=0)
    score: int | None = Field(default=None, ge=0)
    answers: dict[str, Any] | None = None
    model_config = ConfigDict(extra="forbid")


class Questionnaire(BaseModel):
    id: int
    patient_id: int
    filled_by: int | None = None
    score: int
    answers: dict[str, Any]
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class DiagnosisBase(BaseModel):
    patient_id: int = Field(gt=0)
    doctor_id: int | None = Field(default=None, gt=0)
    questionnaire_id: int | None = Field(default=None, gt=0)
    model_result: str = Field(min_length=1, max_length=5000)
    confidence_score: float | None = Field(default=None, ge=0)
    questionnaire_score: int | None = None
    final_medical_opinion: str | None = Field(default=None, max_length=5000)


class DiagnosisCreate(DiagnosisBase):
    pass


class DiagnosisUpdate(BaseModel):
    patient_id: int | None = Field(default=None, gt=0)
    doctor_id: int | None = Field(default=None, gt=0)
    questionnaire_id: int | None = Field(default=None, gt=0)
    model_result: str | None = Field(default=None, min_length=1, max_length=5000)
    confidence_score: float | None = Field(default=None, ge=0)
    questionnaire_score: int | None = None
    final_medical_opinion: str | None = Field(default=None, max_length=5000)
    model_config = ConfigDict(extra="forbid")


class Diagnosis(BaseModel):
    id: int
    patient_id: int
    doctor_id: int | None = None
    questionnaire_id: int | None = None
    model_result: str
    confidence_score: float | None = None
    questionnaire_score: int | None = None
    final_medical_opinion: str | None = None
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class AlertBase(BaseModel):
    patient_id: int = Field(gt=0)
    type: str = Field(min_length=1, max_length=100)
    message: str = Field(min_length=1, max_length=5000)
    is_read: bool = False


class AlertCreate(AlertBase):
    pass


class AlertUpdate(BaseModel):
    patient_id: int | None = Field(default=None, gt=0)
    type: str | None = Field(default=None, min_length=1, max_length=100)
    message: str | None = Field(default=None, min_length=1, max_length=5000)
    is_read: bool | None = None
    model_config = ConfigDict(extra="forbid")


class Alert(BaseModel):
    id: int
    patient_id: int
    type: str
    message: str
    is_read: bool
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class MedicalNoteBase(BaseModel):
    patient_id: int = Field(gt=0)
    doctor_id: int | None = Field(default=None, gt=0)
    note: str = Field(min_length=1, max_length=5000)


class MedicalNoteCreate(MedicalNoteBase):
    pass


class MedicalNoteUpdate(BaseModel):
    patient_id: int | None = Field(default=None, gt=0)
    doctor_id: int | None = Field(default=None, gt=0)
    note: str | None = Field(default=None, min_length=1, max_length=5000)
    model_config = ConfigDict(extra="forbid")


class MedicalNote(BaseModel):
    id: int
    patient_id: int
    doctor_id: int | None = None
    note: str
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)
