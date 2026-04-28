export interface Patient {
  id: number
  patient_code: string
  first_name: string
  last_name: string
  birth_date: string
  cin: string
  created_at: string | null
  status?: PatientStatus | null
}

export interface PatientCreateInput {
  first_name: string
  last_name: string
  birth_date: string
  cin: string
}

export interface DoctorPatientLink {
  doctor_id: number
  patient_id: number
}

export interface PatientDoctorSummary {
  id: number
  first_name: string
  last_name: string
  cin: string
  email: string
  role: 'doctor'
}

export type PatientStatus = 'suivi' | 'nouveau' | 'a_verifier'

export type AppointmentStatus = 'scheduled' | 'done' | 'cancelled' | 'missed'

export interface PatientAppointment {
  id: number
  patient_id: number
  doctor_id: number
  appointment_date: string
  notes: string | null
  status: AppointmentStatus
  created_at: string | null
}

export interface DoctorAppointmentSummary {
  id: number
  patient_id: number
  doctor_id: number
  appointment_date: string
  notes: string | null
  status: AppointmentStatus
}

export type MedicationStatus = 'active' | 'completed' | 'stopped'

export interface PatientMedication {
  id: number
  prescription_id: number | null
  patient_id: number | null
  doctor_id: number | null
  name: string
  dosage: string | null
  form: string | null
  quantity: string | null
  frequency: string | null
  period: string | null
  start_date: string | null
  end_date: string | null
  instructions: string | null
  status: MedicationStatus
  intake_count_per_day: number | null
  duration_days: number | null
  schedule_mode: string | null
  allow_family_adjustment: boolean | null
  is_as_needed: boolean | null
  prescribed_at: string | null
  created_at: string | null
}

export type ActiveMedication = PatientMedication

export type PrescriptionStatus = 'active' | 'completed' | 'cancelled'

export interface Prescription {
  id: number
  patient_id: number
  doctor_id: number
  prescription_date: string
  notes: string | null
  status: PrescriptionStatus
  created_at: string | null
}

export interface PrescriptionCreate {
  patient_id: number
  prescription_date: string
  notes: string | null
  status?: PrescriptionStatus
}

export interface PrescriptionItem {
  name: string
  dosage: string
  form: string | null
  quantity: string
  frequency: string
  period: string
  start_date: string
  end_date: string | null
  instructions: string
}

export interface MedicationFormData {
  name: string
  dosage: string
  form: string
  quantity: string
  frequency: string
  period: string
  startDate: string
  endDate: string
  instructions: string
}

export interface PrescriptionDetail {
  prescription: Prescription
  medications: PatientMedication[]
}

export interface Diagnosis {
  id: number
  patient_id: number
  doctor_id: number | null
  questionnaire_id: number | null
  model_result: string
  confidence_score: number | null
  questionnaire_score: number | null
  final_medical_opinion: string | null
  created_at: string | null
}

export interface MedicalNote {
  id: number
  patient_id: number
  doctor_id: number | null
  note: string
  created_at: string | null
}

export type AllergySeverity = 'low' | 'moderate' | 'high' | 'critical'

export interface PatientAllergy {
  id: number
  patient_id: number
  doctor_id: number | null
  allergen: string
  reaction: string | null
  severity: AllergySeverity
  notes: string | null
  created_at: string | null
}

export interface PatientAllergyCreate {
  allergen: string
  reaction: string
  severity: AllergySeverity
  notes?: string | null
}

export interface PatientLocation {
  id: number
  patient_id: number
  latitude: number
  longitude: number
  recorded_at: string
}

export interface PatientAlert {
  id: number
  patient_id: number
  type: string
  message: string
  is_read: boolean
  created_at: string | null
}
