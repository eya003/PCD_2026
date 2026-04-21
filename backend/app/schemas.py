from datetime import date, datetime, time
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class PatientBase(BaseModel):
    patient_code: str = Field(min_length=1, max_length=50)
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    birth_date: date
    cin: str = Field(min_length=3, max_length=20)


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
    cin: str | None = Field(default=None, min_length=3, max_length=20)
    model_config = ConfigDict(extra="forbid")


UserRole = Literal["doctor", "family"]
FamilyAccessRole = Literal["admin", "viewer"]
AppointmentStatus = Literal["scheduled", "done", "cancelled", "missed"]
PrescriptionStatus = Literal["active", "completed", "cancelled"]
MedicationStatus = Literal["active", "completed", "stopped"]
MedicationScheduleMode = Literal["fixed_times", "default_times", "distributed"]
MedicationIntakeStatus = Literal["taken", "missed", "skipped", "rescheduled"]
ScheduledDoseStatus = Literal[
    "pending",
    "taken",
    "missed",
    "skipped",
    "rescheduled",
    "cancelled",
]
ScheduledDoseValidationMethod = Literal["manual", "auto", "system"]
DoseNotificationChannel = Literal["local", "push"]
DoseNotificationStatus = Literal["pending", "sent", "failed", "cancelled"]
AllergySeverity = str


class UserBase(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    cin: str = Field(min_length=3, max_length=20)
    email: str = Field(min_length=3, max_length=150)
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
    cin: str = Field(min_length=3, max_length=20)
    email: str = Field(min_length=3, max_length=150)
    password: str = Field(min_length=6, max_length=128)


class RegisterFamilyRequest(RegisterDoctorRequest):
    patient_cin: str = Field(min_length=3, max_length=20)
    family_role: FamilyAccessRole
    relation_to_patient: str = Field(min_length=1, max_length=30)


class RegisterLegacyRequest(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    cin: str = Field(min_length=3, max_length=20)
    email: str = Field(min_length=3, max_length=150)
    password: str = Field(min_length=6, max_length=128)
    role: UserRole
    patient_cin: str | None = Field(default=None, min_length=3, max_length=20)
    family_role: FamilyAccessRole | None = None
    relation_to_patient: str | None = Field(default=None, min_length=1, max_length=30)


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
    relation_to_patient: str = Field(default="unspecified", min_length=1, max_length=30)


class FamilyPatientLink(BaseModel):
    user_id: int
    patient_id: int
    family_role: FamilyAccessRole
    relation_to_patient: str | None = None
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
    name: str = Field(min_length=1, max_length=150)
    dosage: str = Field(min_length=1, max_length=100)
    form: str | None = Field(default=None, min_length=1, max_length=50)
    quantity: str | None = Field(default=None, min_length=1, max_length=100)
    frequency: str = Field(min_length=1, max_length=100)
    period: str | None = Field(default=None, min_length=1, max_length=100)
    start_date: date
    end_date: date | None = None
    instructions: str | None = Field(default=None, max_length=5000)
    status: MedicationStatus = "active"
    intake_count_per_day: int | None = Field(default=None, gt=0)
    duration_days: int | None = Field(default=None, gt=0)
    schedule_mode: MedicationScheduleMode | None = "default_times"
    day_start_time: time | None = None
    day_end_time: time | None = None
    specific_times: list[time] | None = Field(default=None, min_length=1)
    allow_family_adjustment: bool = True
    is_as_needed: bool = False

    @model_validator(mode="after")
    def validate_dates_and_window(self):
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        if (
            self.day_start_time is not None
            and self.day_end_time is not None
            and self.day_end_time <= self.day_start_time
        ):
            raise ValueError("day_end_time must be strictly after day_start_time")
        return self


class MedicationDoctorInputBase(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    dosage: str = Field(min_length=1, max_length=100)
    form: str | None = Field(default=None, min_length=1, max_length=50)
    quantity: str | None = Field(default=None, min_length=1, max_length=100)
    frequency: str = Field(min_length=1, max_length=100)
    period: str | None = Field(default=None, min_length=1, max_length=100)
    duration: str | None = Field(default=None, min_length=1, max_length=100)
    start_date: date
    end_date: date | None = None
    instructions: str | None = Field(default=None, max_length=5000)
    is_as_needed: bool = False
    model_config = ConfigDict(extra="ignore")

    @model_validator(mode="after")
    def validate_dates(self):
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        return self


class MedicationDoctorCreateItem(MedicationDoctorInputBase):
    pass


class PrescriptionWithItemsCreate(BaseModel):
    patient_id: int = Field(gt=0)
    prescription_date: date | None = None
    notes: str | None = Field(default=None, max_length=5000)
    status: PrescriptionStatus = "active"
    medications: list[MedicationDoctorCreateItem] = Field(min_length=1)


class PrescriptionWithItemsResponse(BaseModel):
    prescription: "Prescription"
    medications: list["Medication"]
    model_config = ConfigDict(from_attributes=True)


class MedicationBase(BaseModel):
    prescription_id: int | None = Field(default=None, gt=0)
    patient_id: int = Field(gt=0)
    doctor_id: int | None = Field(default=None, gt=0)
    name: str = Field(min_length=1, max_length=150)
    dosage: str = Field(min_length=1, max_length=100)
    form: str | None = Field(default=None, min_length=1, max_length=50)
    quantity: str | None = Field(default=None, min_length=1, max_length=100)
    frequency: str = Field(min_length=1, max_length=100)
    period: str | None = Field(default=None, min_length=1, max_length=100)
    start_date: date
    end_date: date | None = None
    instructions: str | None = Field(default=None, max_length=5000)
    status: MedicationStatus = "active"
    intake_count_per_day: int | None = Field(default=None, gt=0)
    duration_days: int | None = Field(default=None, gt=0)
    schedule_mode: MedicationScheduleMode | None = "default_times"
    day_start_time: time | None = None
    day_end_time: time | None = None
    specific_times: list[time] | None = Field(default=None, min_length=1)
    allow_family_adjustment: bool = True
    is_as_needed: bool = False

    @model_validator(mode="after")
    def validate_dates_and_window(self):
        if self.end_date is not None and self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        if (
            self.day_start_time is not None
            and self.day_end_time is not None
            and self.day_end_time <= self.day_start_time
        ):
            raise ValueError("day_end_time must be strictly after day_start_time")
        return self


class MedicationCreate(MedicationBase):
    pass


class MedicationDoctorCreate(MedicationDoctorInputBase):
    patient_id: int = Field(gt=0)
    prescription_id: int | None = Field(default=None, gt=0)


class MedicationUpdate(BaseModel):
    prescription_id: int | None = Field(default=None, gt=0)
    patient_id: int | None = Field(default=None, gt=0)
    doctor_id: int | None = Field(default=None, gt=0)
    name: str | None = Field(default=None, min_length=1, max_length=150)
    dosage: str | None = Field(default=None, min_length=1, max_length=100)
    form: str | None = Field(default=None, min_length=1, max_length=50)
    quantity: str | None = Field(default=None, min_length=1, max_length=100)
    frequency: str | None = Field(default=None, min_length=1, max_length=100)
    period: str | None = Field(default=None, min_length=1, max_length=100)
    start_date: date | None = None
    end_date: date | None = None
    instructions: str | None = Field(default=None, max_length=5000)
    status: MedicationStatus | None = None
    intake_count_per_day: int | None = Field(default=None, gt=0)
    duration_days: int | None = Field(default=None, gt=0)
    schedule_mode: MedicationScheduleMode | None = None
    day_start_time: time | None = None
    day_end_time: time | None = None
    specific_times: list[time] | None = Field(default=None, min_length=1)
    allow_family_adjustment: bool | None = None
    is_as_needed: bool | None = None
    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="after")
    def validate_dates_and_window(self):
        if (
            self.start_date is not None
            and self.end_date is not None
            and self.end_date < self.start_date
        ):
            raise ValueError("end_date must be on or after start_date")
        if (
            self.day_start_time is not None
            and self.day_end_time is not None
            and self.day_end_time <= self.day_start_time
        ):
            raise ValueError("day_end_time must be strictly after day_start_time")
        return self


class Medication(MedicationBase):
    id: int
    prescribed_at: datetime | None = None
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class MedicationSummary(BaseModel):
    id: int
    prescription_id: int | None = None
    patient_id: int | None = None
    doctor_id: int | None = None
    name: str
    dosage: str | None = None
    form: str | None = None
    quantity: str | None = None
    frequency: str | None = None
    period: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    instructions: str | None = None
    status: MedicationStatus
    intake_count_per_day: int | None = None
    duration_days: int | None = None
    schedule_mode: MedicationScheduleMode | None = None
    day_start_time: time | None = None
    day_end_time: time | None = None
    specific_times: list[time] | None = None
    allow_family_adjustment: bool | None = None
    is_as_needed: bool | None = None
    prescribed_at: datetime | None = None
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class MedicationIntakeBase(BaseModel):
    medication_id: int = Field(gt=0)
    scheduled_dose_id: int | None = Field(default=None, gt=0)
    scheduled_for: datetime | None = None
    taken_at: datetime = Field(default_factory=datetime.utcnow)
    status: MedicationIntakeStatus
    comment: str | None = Field(default=None, max_length=5000)


class MedicationIntakeCreate(MedicationIntakeBase):
    pass


class MedicationIntakeUpdate(BaseModel):
    medication_id: int | None = Field(default=None, gt=0)
    scheduled_dose_id: int | None = Field(default=None, gt=0)
    scheduled_for: datetime | None = None
    taken_at: datetime | None = None
    status: MedicationIntakeStatus | None = None
    comment: str | None = Field(default=None, max_length=5000)
    model_config = ConfigDict(extra="forbid")


class MedicationIntake(MedicationIntakeBase):
    id: int
    validated_by: int | None = None
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class MedicationScheduleTemplateBase(BaseModel):
    morning_time: time = time(8, 0)
    noon_time: time = time(13, 0)
    evening_time: time = time(20, 0)
    day_start_time: time = time(8, 0)
    day_end_time: time = time(23, 0)
    reminder_offset_minutes: int = Field(default=10, ge=0, le=1440)
    allow_family_adjustment: bool = True
    is_active: bool = True

    @model_validator(mode="after")
    def validate_day_window(self):
        if self.day_end_time <= self.day_start_time:
            raise ValueError("day_end_time must be strictly after day_start_time")
        return self


class MedicationScheduleTemplateCreate(MedicationScheduleTemplateBase):
    patient_id: int = Field(gt=0)
    created_by: int | None = Field(default=None, gt=0)


class MedicationScheduleTemplateUpdate(BaseModel):
    morning_time: time | None = None
    noon_time: time | None = None
    evening_time: time | None = None
    day_start_time: time | None = None
    day_end_time: time | None = None
    reminder_offset_minutes: int | None = Field(default=None, ge=0, le=1440)
    allow_family_adjustment: bool | None = None
    is_active: bool | None = None
    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="after")
    def validate_day_window(self):
        if (
            self.day_start_time is not None
            and self.day_end_time is not None
            and self.day_end_time <= self.day_start_time
        ):
            raise ValueError("day_end_time must be strictly after day_start_time")
        return self


class MedicationScheduleTemplate(MedicationScheduleTemplateBase):
    id: int
    patient_id: int
    created_by: int | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class DoseNotificationBase(BaseModel):
    scheduled_dose_id: int = Field(gt=0)
    patient_id: int = Field(gt=0)
    recipient_user_id: int | None = Field(default=None, gt=0)
    channel: DoseNotificationChannel = "local"
    send_at: datetime
    status: DoseNotificationStatus = "pending"
    error_message: str | None = Field(default=None, max_length=5000)


class DoseNotificationCreate(DoseNotificationBase):
    pass


class DoseNotificationUpdate(BaseModel):
    recipient_user_id: int | None = Field(default=None, gt=0)
    channel: DoseNotificationChannel | None = None
    send_at: datetime | None = None
    sent_at: datetime | None = None
    status: DoseNotificationStatus | None = None
    error_message: str | None = Field(default=None, max_length=5000)
    model_config = ConfigDict(extra="forbid")


class DoseNotification(DoseNotificationBase):
    id: int
    sent_at: datetime | None = None
    created_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class ScheduledMedicationDoseBase(BaseModel):
    patient_id: int = Field(gt=0)
    medication_id: int = Field(gt=0)
    prescription_id: int | None = Field(default=None, gt=0)
    scheduled_date: date
    scheduled_time: time
    scheduled_for: datetime
    period_label: str | None = Field(default=None, max_length=30)
    status: ScheduledDoseStatus = "pending"
    original_scheduled_for: datetime | None = None
    rescheduled_for: datetime | None = None
    taken_at: datetime | None = None
    validated_by: int | None = Field(default=None, gt=0)
    validation_method: ScheduledDoseValidationMethod | None = "manual"
    skipped_reason: str | None = Field(default=None, max_length=5000)
    notes: str | None = Field(default=None, max_length=5000)


class ScheduledMedicationDoseCreate(ScheduledMedicationDoseBase):
    pass


class ScheduledMedicationDoseUpdate(BaseModel):
    patient_id: int | None = Field(default=None, gt=0)
    medication_id: int | None = Field(default=None, gt=0)
    prescription_id: int | None = Field(default=None, gt=0)
    scheduled_date: date | None = None
    scheduled_time: time | None = None
    scheduled_for: datetime | None = None
    period_label: str | None = Field(default=None, max_length=30)
    status: ScheduledDoseStatus | None = None
    original_scheduled_for: datetime | None = None
    rescheduled_for: datetime | None = None
    taken_at: datetime | None = None
    validated_by: int | None = Field(default=None, gt=0)
    validation_method: ScheduledDoseValidationMethod | None = None
    skipped_reason: str | None = Field(default=None, max_length=5000)
    notes: str | None = Field(default=None, max_length=5000)
    model_config = ConfigDict(extra="forbid")


class ScheduledMedicationDose(ScheduledMedicationDoseBase):
    id: int
    created_at: datetime | None = None
    updated_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class ScheduledMedicationDoseWithMedication(ScheduledMedicationDose):
    medication: MedicationSummary | None = None


class ScheduledMedicationDoseDetail(ScheduledMedicationDoseWithMedication):
    intakes: list[MedicationIntake] = Field(default_factory=list)
    notifications: list[DoseNotification] = Field(default_factory=list)


class ScheduledDoseTakeAction(BaseModel):
    taken_at: datetime | None = None
    validation_method: ScheduledDoseValidationMethod = "manual"
    notes: str | None = Field(default=None, max_length=5000)
    comment: str | None = Field(default=None, max_length=5000)
    create_intake_log: bool = True
    model_config = ConfigDict(extra="forbid")


class ScheduledDoseMissAction(BaseModel):
    missed_at: datetime | None = None
    validation_method: ScheduledDoseValidationMethod = "manual"
    notes: str | None = Field(default=None, max_length=5000)
    comment: str | None = Field(default=None, max_length=5000)
    create_intake_log: bool = True
    model_config = ConfigDict(extra="forbid")


class ScheduledDoseSkipAction(BaseModel):
    skipped_reason: str = Field(min_length=1, max_length=5000)
    skipped_at: datetime | None = None
    validation_method: ScheduledDoseValidationMethod = "manual"
    notes: str | None = Field(default=None, max_length=5000)
    comment: str | None = Field(default=None, max_length=5000)
    create_intake_log: bool = True
    model_config = ConfigDict(extra="forbid")


class ScheduledDoseRescheduleAction(BaseModel):
    rescheduled_for: datetime
    reason: str | None = Field(default=None, max_length=5000)
    notes: str | None = Field(default=None, max_length=5000)
    validation_method: ScheduledDoseValidationMethod = "manual"
    model_config = ConfigDict(extra="forbid")


class ScheduledDoseCancelAction(BaseModel):
    reason: str | None = Field(default=None, max_length=5000)
    notes: str | None = Field(default=None, max_length=5000)
    model_config = ConfigDict(extra="forbid")


class ScheduledDoseActionResult(BaseModel):
    dose: ScheduledMedicationDose
    intake: MedicationIntake | None = None
    model_config = ConfigDict(from_attributes=True)


class DoseStatusCounts(BaseModel):
    pending: int = 0
    taken: int = 0
    missed: int = 0
    skipped: int = 0
    rescheduled: int = 0
    cancelled: int = 0
    total: int = 0


class DayPlanningRead(BaseModel):
    patient_id: int
    date: date
    doses: list[ScheduledMedicationDoseWithMedication] = Field(default_factory=list)
    counts: DoseStatusCounts = Field(default_factory=DoseStatusCounts)


class PlanningDayBucket(BaseModel):
    date: date
    doses: list[ScheduledMedicationDoseWithMedication] = Field(default_factory=list)
    counts: DoseStatusCounts = Field(default_factory=DoseStatusCounts)


class DateRangePlanningRead(BaseModel):
    patient_id: int
    start_date: date
    end_date: date
    days: list[PlanningDayBucket] = Field(default_factory=list)
    counts: DoseStatusCounts = Field(default_factory=DoseStatusCounts)


class DateRangePlanningQuery(BaseModel):
    patient_id: int = Field(gt=0)
    start_date: date
    end_date: date

    @model_validator(mode="after")
    def validate_range(self):
        if self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        return self


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


class PatientSafeZoneUpdate(BaseModel):
    origin_latitude: float = Field(ge=-90, le=90)
    origin_longitude: float = Field(ge=-180, le=180)
    radius_meters: float = Field(gt=0)


class PatientSafeZone(BaseModel):
    patient_id: int
    origin_latitude: float
    origin_longitude: float
    radius_meters: float
    updated_at: datetime | None = None
    updated_by: int | None = None
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


PrescriptionWithItemsResponse.model_rebuild()
ScheduledMedicationDoseWithMedication.model_rebuild()
ScheduledMedicationDoseDetail.model_rebuild()
ScheduledDoseActionResult.model_rebuild()
