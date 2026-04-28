import { isApiError } from '../../../core/api/axiosClient'
import axiosClient from '../../../core/api/axiosClient'
import type {
  ActiveMedication,
  AllergySeverity,
  AppointmentStatus,
  Diagnosis,
  DoctorPatientLink,
  DoctorAppointmentSummary,
  MedicalNote,
  MedicationStatus,
  PatientAllergy,
  PatientAllergyCreate,
  PatientAlert,
  PatientCreateInput,
  PatientDoctorSummary,
  Patient,
  PatientAppointment,
  PatientLocation,
  PatientMedication,
  Prescription,
  PrescriptionCreate,
  PrescriptionItem,
  PrescriptionStatus,
  PatientStatus,
} from '../types'

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function asNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }
  if (typeof value === 'string') {
    const parsed = Number.parseInt(value, 10)
    if (Number.isFinite(parsed)) {
      return parsed
    }
  }
  return null
}

function asString(value: unknown): string | null {
  if (typeof value === 'string') {
    return value
  }
  return null
}

function asNullableString(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null
  }
  return asString(value)
}

function asNullableNumber(value: unknown): number | null {
  if (value === null || value === undefined) {
    return null
  }
  return asNumber(value)
}

function asNullableBoolean(value: unknown): boolean | null {
  if (typeof value === 'boolean') {
    return value
  }
  return null
}

function asPatientStatus(value: unknown): PatientStatus | null {
  if (typeof value !== 'string') {
    return null
  }

  const normalized = value.trim().toLowerCase()
  if (normalized === 'suivi') return 'suivi'
  if (normalized === 'nouveau') return 'nouveau'
  if (normalized === 'a_verifier' || normalized === 'a verifier') {
    return 'a_verifier'
  }
  return null
}

function parseArray<T>(
  data: unknown,
  parser: (item: unknown) => T,
  invalidMessage: string,
): T[] {
  if (!Array.isArray(data)) {
    throw new Error(invalidMessage)
  }
  return data.map(parser)
}

function parsePatient(data: unknown): Patient {
  if (!isRecord(data)) {
    throw new Error('Format patient invalide.')
  }

  const id = asNumber(data.id)
  const patientCode = asNullableString(data.patient_code)
  const firstName = asString(data.first_name)
  const lastName = asString(data.last_name)
  const birthDate = asString(data.birth_date)
  const cin = asString(data.cin)
  const createdAtValue = data.created_at

  const createdAt =
    createdAtValue === null ? null : asString(createdAtValue) ?? null

  if (
    id === null ||
    firstName === null ||
    lastName === null ||
    birthDate === null ||
    cin === null
  ) {
    throw new Error('Donnees patient incompletes.')
  }

  return {
    id,
    patient_code:
      patientCode && patientCode.trim().length > 0
        ? patientCode
        : `P-${id}`,
    first_name: firstName,
    last_name: lastName,
    birth_date: birthDate,
    cin,
    created_at: createdAt,
    status: asPatientStatus(data.status),
  }
}

function buildPatientCode(cin: string): string {
  const cleaned = cin
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
  const fallback = Date.now().toString()
  const base = cleaned.length > 0 ? cleaned : fallback
  const code = `P${base}`
  return code.length <= 50 ? code : code.slice(0, 50)
}

function parsePatientDoctorSummary(data: unknown): PatientDoctorSummary {
  if (!isRecord(data)) {
    throw new Error('Format medecin patient invalide.')
  }

  const id = asNumber(data.id)
  const firstName = asString(data.first_name)
  const lastName = asString(data.last_name)
  const cin = asString(data.cin)
  const email = asString(data.email)
  const role = asString(data.role)

  if (
    id === null ||
    firstName === null ||
    lastName === null ||
    cin === null ||
    email === null ||
    role !== 'doctor'
  ) {
    throw new Error('Donnees medecin patient incompletes.')
  }

  return {
    id,
    first_name: firstName,
    last_name: lastName,
    cin,
    email,
    role: 'doctor',
  }
}

function parseAppointment(data: unknown): PatientAppointment {
  if (!isRecord(data)) {
    throw new Error('Format rendez-vous invalide.')
  }

  const id = asNumber(data.id)
  const patientId = asNumber(data.patient_id)
  const doctorId = asNumber(data.doctor_id)
  const appointmentDate = asString(data.appointment_date)
  const notes = asNullableString(data.notes)
  const status = asString(data.status)
  const createdAt = asNullableString(data.created_at)

  if (
    id === null ||
    patientId === null ||
    doctorId === null ||
    appointmentDate === null ||
    status === null
  ) {
    throw new Error('Donnees rendez-vous incompletes.')
  }

  if (
    status !== 'scheduled' &&
    status !== 'done' &&
    status !== 'cancelled' &&
    status !== 'missed'
  ) {
    throw new Error('Statut rendez-vous invalide.')
  }

  return {
    id,
    patient_id: patientId,
    doctor_id: doctorId,
    appointment_date: appointmentDate,
    notes,
    status,
    created_at: createdAt,
  }
}

interface AppointmentMutationPayload {
  appointmentDate: string
  doctorId: number
  notes?: string | null
  patientId: number
  status?: AppointmentStatus
}

interface AppointmentUpdatePayload extends AppointmentMutationPayload {
  appointmentId: number
}

interface MarkAppointmentCompletedPayload {
  appointment: PatientAppointment
  doctorId: number
}

interface MedicationIntakeCreatePayload {
  medicationId: number
  status: 'taken' | 'missed'
}

type PatientAllergyCreatePayload = PatientAllergyCreate
type PatientCreatePayload = PatientCreateInput

export interface PrescriptionCreatePayload {
  patientId: number
  prescriptionDate: string
  notes?: string | null
  status?: PrescriptionStatus
}

export interface PrescriptionWithItemsPayload extends PrescriptionCreatePayload {
  doctorId: number
  medications: PrescriptionItem[]
}

export interface PrescriptionWithItemsResult {
  prescription: Prescription
  medications: PatientMedication[]
}

export interface MedicationMutationPayload {
  patientId: number
  doctorId: number
  prescriptionId?: number | null
  name: string
  dosage: string
  form?: string | null
  quantity: string
  frequency: string
  period: string
  startDate: string
  endDate?: string | null
  instructions: string
}

export interface MedicationUpdatePayload extends MedicationMutationPayload {
  medicationId: number
}

function normalizeOutgoingStatus(rawStatus: string): AppointmentStatus {
  const value = rawStatus.trim().toLowerCase()
  if (value === 'done' || value === 'completed' || value === 'termine') {
    return 'done'
  }
  if (value === 'cancelled' || value === 'canceled' || value === 'annule') {
    return 'cancelled'
  }
  if (value === 'missed' || value === 'manque') {
    return 'missed'
  }
  return 'scheduled'
}

function normalizeNotes(value: string | null | undefined): string | null {
  const text = value?.trim() ?? ''
  return text.length > 0 ? text : null
}

function buildAppointmentBody({
  appointmentDate,
  doctorId,
  notes,
  patientId,
  status,
}: AppointmentMutationPayload): Record<string, unknown> {
  return {
    patient_id: patientId,
    doctor_id: doctorId,
    appointment_date: appointmentDate,
    notes: normalizeNotes(notes),
    status: normalizeOutgoingStatus(status ?? 'scheduled'),
  }
}

function normalizeMedicationStatus(rawStatus: string): MedicationStatus {
  const value = rawStatus.trim().toLowerCase()
  if (value === 'completed' || value === 'done' || value === 'termine') {
    return 'completed'
  }
  if (
    value === 'stopped' ||
    value === 'stop' ||
    value === 'cancelled' ||
    value === 'canceled' ||
    value === 'cancel' ||
    value === 'annule'
  ) {
    return 'stopped'
  }
  return 'active'
}

function normalizePrescriptionStatus(rawStatus: string): PrescriptionStatus {
  const value = rawStatus.trim().toLowerCase()
  if (value === 'completed' || value === 'done' || value === 'terminee') {
    return 'completed'
  }
  if (
    value === 'cancelled' ||
    value === 'canceled' ||
    value === 'cancel' ||
    value === 'annulee'
  ) {
    return 'cancelled'
  }
  return 'active'
}

function normalizeAllergySeverity(rawSeverity: string): AllergySeverity {
  const value = rawSeverity.trim().toLowerCase()
  if (value === 'low') return 'low'
  if (value === 'high') return 'high'
  if (value === 'critical') return 'critical'
  return 'moderate'
}

function normalizeOptionalText(value: string | null | undefined): string | null {
  const text = value?.trim() ?? ''
  return text.length > 0 ? text : null
}

function buildMedicationBody(
  payload: MedicationMutationPayload,
): Record<string, unknown> {
  const body: Record<string, unknown> = {
    patient_id: payload.patientId,
    doctor_id: payload.doctorId,
    name: payload.name.trim(),
    dosage: payload.dosage.trim(),
    form: normalizeOptionalText(payload.form),
    quantity: normalizeOptionalText(payload.quantity),
    frequency: payload.frequency.trim(),
    period: normalizeOptionalText(payload.period),
    start_date: payload.startDate,
    end_date: normalizeOptionalText(payload.endDate),
    instructions: normalizeOptionalText(payload.instructions),
  }

  if (payload.prescriptionId !== undefined) {
    body.prescription_id = payload.prescriptionId
  }

  return body
}

function parseMedication(data: unknown): PatientMedication {
  if (!isRecord(data)) {
    throw new Error('Format medicament invalide.')
  }

  const id = asNumber(data.id)
  const name = asString(data.name)
  const rawStatus = asString(data.status)

  if (id === null || name === null || rawStatus === null) {
    throw new Error('Donnees medicament incompletes.')
  }

  return {
    id,
    prescription_id: asNullableNumber(data.prescription_id),
    patient_id: asNullableNumber(data.patient_id),
    doctor_id: asNullableNumber(data.doctor_id),
    name,
    dosage: asNullableString(data.dosage),
    form: asNullableString(data.form),
    quantity: asNullableString(data.quantity),
    frequency: asNullableString(data.frequency),
    period: asNullableString(data.period),
    start_date: asNullableString(data.start_date),
    end_date: asNullableString(data.end_date),
    instructions: asNullableString(data.instructions),
    status: normalizeMedicationStatus(rawStatus),
    intake_count_per_day: asNullableNumber(data.intake_count_per_day),
    duration_days: asNullableNumber(data.duration_days),
    schedule_mode: asNullableString(data.schedule_mode),
    allow_family_adjustment: asNullableBoolean(data.allow_family_adjustment),
    is_as_needed: asNullableBoolean(data.is_as_needed),
    prescribed_at: asNullableString(data.prescribed_at),
    created_at: asNullableString(data.created_at),
  }
}

function parsePrescription(data: unknown): Prescription {
  if (!isRecord(data)) {
    throw new Error('Format ordonnance invalide.')
  }

  const id = asNumber(data.id)
  const patientId = asNumber(data.patient_id)
  const doctorId = asNumber(data.doctor_id)
  const prescriptionDate = asString(data.prescription_date)
  const notes = asNullableString(data.notes)
  const rawStatus = asString(data.status)
  const createdAt = asNullableString(data.created_at)

  if (
    id === null ||
    patientId === null ||
    doctorId === null ||
    prescriptionDate === null ||
    rawStatus === null
  ) {
    throw new Error('Donnees ordonnance incompletes.')
  }

  return {
    id,
    patient_id: patientId,
    doctor_id: doctorId,
    prescription_date: prescriptionDate,
    notes,
    status: normalizePrescriptionStatus(rawStatus),
    created_at: createdAt,
  }
}

function buildPrescriptionBody({
  patientId,
  prescriptionDate,
  notes,
  status = 'active',
}: PrescriptionCreatePayload): PrescriptionCreate {
  return {
    patient_id: patientId,
    prescription_date: prescriptionDate,
    notes: normalizeOptionalText(notes),
    status: normalizePrescriptionStatus(status),
  }
}

function buildPrescriptionMedicationBody(item: PrescriptionItem): Record<string, unknown> {
  return {
    name: item.name.trim(),
    dosage: item.dosage.trim(),
    form: normalizeOptionalText(item.form),
    quantity: normalizeOptionalText(item.quantity),
    frequency: item.frequency.trim(),
    period: normalizeOptionalText(item.period),
    start_date: item.start_date,
    end_date: normalizeOptionalText(item.end_date),
    instructions: normalizeOptionalText(item.instructions),
  }
}

function parseDiagnosis(data: unknown): Diagnosis {
  if (!isRecord(data)) {
    throw new Error('Format diagnostic invalide.')
  }

  const id = asNumber(data.id)
  const patientId = asNumber(data.patient_id)
  const modelResult = asString(data.model_result)

  if (id === null || patientId === null || modelResult === null) {
    throw new Error('Donnees diagnostic incompletes.')
  }

  return {
    id,
    patient_id: patientId,
    doctor_id: asNullableNumber(data.doctor_id),
    questionnaire_id: asNullableNumber(data.questionnaire_id),
    model_result: modelResult,
    confidence_score: asNullableNumber(data.confidence_score),
    questionnaire_score: asNullableNumber(data.questionnaire_score),
    final_medical_opinion: asNullableString(data.final_medical_opinion),
    created_at: asNullableString(data.created_at),
  }
}

function parseMedicalNote(data: unknown): MedicalNote {
  if (!isRecord(data)) {
    throw new Error('Format note medicale invalide.')
  }

  const id = asNumber(data.id)
  const patientId = asNumber(data.patient_id)
  const note = asString(data.note)

  if (id === null || patientId === null || note === null) {
    throw new Error('Donnees note medicale incompletes.')
  }

  return {
    id,
    patient_id: patientId,
    doctor_id: asNullableNumber(data.doctor_id),
    note,
    created_at: asNullableString(data.created_at),
  }
}

function parsePatientLocation(data: unknown): PatientLocation {
  if (!isRecord(data)) {
    throw new Error('Format localisation invalide.')
  }

  const id = asNumber(data.id)
  const patientId = asNumber(data.patient_id)
  const latitude = asNullableNumber(data.latitude)
  const longitude = asNullableNumber(data.longitude)
  const recordedAt = asString(data.recorded_at)

  if (
    id === null ||
    patientId === null ||
    latitude === null ||
    longitude === null ||
    recordedAt === null
  ) {
    throw new Error('Donnees localisation incompletes.')
  }

  return {
    id,
    patient_id: patientId,
    latitude,
    longitude,
    recorded_at: recordedAt,
  }
}

function parsePatientAlert(data: unknown): PatientAlert {
  if (!isRecord(data)) {
    throw new Error('Format alerte invalide.')
  }

  const id = asNumber(data.id)
  const patientId = asNumber(data.patient_id)
  const type = asString(data.type)
  const message = asString(data.message)
  const isRead = asNullableBoolean(data.is_read)
  const createdAt = asNullableString(data.created_at)

  if (
    id === null ||
    patientId === null ||
    type === null ||
    message === null ||
    isRead === null
  ) {
    throw new Error('Donnees alerte incompletes.')
  }

  return {
    id,
    patient_id: patientId,
    type,
    message,
    is_read: isRead,
    created_at: createdAt,
  }
}

function parsePatientAllergy(data: unknown): PatientAllergy {
  if (!isRecord(data)) {
    throw new Error('Format allergie invalide.')
  }

  const id = asNumber(data.id)
  const patientId = asNumber(data.patient_id)
  const allergen = asString(data.allergen)
  const rawSeverity = asNullableString(data.severity)

  if (id === null || patientId === null || allergen === null) {
    throw new Error('Donnees allergie incompletes.')
  }

  return {
    id,
    patient_id: patientId,
    doctor_id: asNullableNumber(data.doctor_id),
    allergen,
    reaction: asNullableString(data.reaction),
    severity: normalizeAllergySeverity(rawSeverity ?? 'moderate'),
    notes: asNullableString(data.notes),
    created_at: asNullableString(data.created_at),
  }
}

function resolveErrorMessage(error: unknown, fallback: string): string {
  if (isApiError(error)) {
    return error.message
  }
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return fallback
}

export async function getDoctorPatients(doctorId: number): Promise<Patient[]> {
  try {
    const response = await axiosClient.get<unknown>(`/doctors/${doctorId}/patients`)
    return parseArray(response.data, parsePatient, 'Format de reponse patients invalide.')
  } catch (error) {
    throw new Error(resolveErrorMessage(error, 'Chargement patients impossible.'), {
      cause: error,
    })
  }
}

export async function getFamilyPatients(userId: number): Promise<Patient[]> {
  try {
    const response = await axiosClient.get<unknown>(`/family/${userId}/patients`)
    return parseArray(response.data, parsePatient, 'Format de reponse patients invalide.')
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Chargement patients famille impossible.'),
      {
        cause: error,
      },
    )
  }
}

export async function createPatient(payload: PatientCreatePayload): Promise<Patient> {
  try {
    const normalizedCin = payload.cin.trim().toUpperCase()
    const response = await axiosClient.post<unknown>('/patients/', {
      patient_code: buildPatientCode(normalizedCin),
      first_name: payload.first_name.trim(),
      last_name: payload.last_name.trim(),
      birth_date: payload.birth_date,
      cin: normalizedCin,
    })
    return parsePatient(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de creer le patient.'),
      {
        cause: error,
      },
    )
  }
}

export async function linkDoctorToPatient(
  doctorId: number,
  patientId: number,
): Promise<DoctorPatientLink> {
  try {
    const response = await axiosClient.post<unknown>('/doctors/link-patient', {
      doctor_id: doctorId,
      patient_id: patientId,
    })

    if (!isRecord(response.data)) {
      throw new Error('Format de reponse lien medecin-patient invalide.')
    }

    const responseDoctorId = asNumber(response.data.doctor_id)
    const responsePatientId = asNumber(response.data.patient_id)
    if (responseDoctorId === null || responsePatientId === null) {
      throw new Error('Donnees lien medecin-patient incompletes.')
    }

    return {
      doctor_id: responseDoctorId,
      patient_id: responsePatientId,
    }
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de lier ce patient au medecin.'),
      {
        cause: error,
      },
    )
  }
}

export async function getPatientDoctors(
  patientId: number,
): Promise<PatientDoctorSummary[]> {
  try {
    const response = await axiosClient.get<unknown>(`/patients/${patientId}/doctors`)
    return parseArray(
      response.data,
      parsePatientDoctorSummary,
      'Format de reponse medecins patient invalide.',
    )
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Chargement medecins patient impossible.'),
      {
        cause: error,
      },
    )
  }
}

export async function getDoctorAppointments(
  doctorId: number,
): Promise<DoctorAppointmentSummary[]> {
  try {
    const response = await axiosClient.get<unknown>(
      `/doctors/${doctorId}/appointments`,
    )
    const items = parseArray(
      response.data,
      parseAppointment,
      'Format de reponse rendez-vous invalide.',
    )
    return items.map((item) => {
      return {
        id: item.id,
        patient_id: item.patient_id,
        doctor_id: item.doctor_id,
        appointment_date: item.appointment_date,
        notes: item.notes,
        status: item.status,
      }
    })
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Chargement rendez-vous medecin impossible.'),
      {
        cause: error,
      },
    )
  }
}

export async function getPatientById(patientId: number): Promise<Patient> {
  try {
    const response = await axiosClient.get<unknown>(`/patients/${patientId}`)
    return parsePatient(response.data)
  } catch (error) {
    throw new Error(resolveErrorMessage(error, 'Chargement patient impossible.'), {
      cause: error,
    })
  }
}

export async function getPatientPrescriptions(
  patientId: number,
): Promise<Prescription[]> {
  try {
    const response = await axiosClient.get<unknown>(
      `/patients/${patientId}/prescriptions`,
    )
    const items = parseArray(
      response.data,
      parsePrescription,
      'Format de reponse ordonnances invalide.',
    )
    return items.sort((a, b) => {
      const left = a.created_at ?? a.prescription_date
      const right = b.created_at ?? b.prescription_date
      return right.localeCompare(left)
    })
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Chargement ordonnances impossible.'),
      {
        cause: error,
      },
    )
  }
}

export async function getPrescriptionById(
  prescriptionId: number,
): Promise<Prescription> {
  try {
    const response = await axiosClient.get<unknown>(`/prescriptions/${prescriptionId}`)
    return parsePrescription(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Chargement detail ordonnance impossible.'),
      {
        cause: error,
      },
    )
  }
}

export async function createPrescription(
  payload: PrescriptionCreatePayload,
): Promise<Prescription> {
  try {
    const response = await axiosClient.post<unknown>(
      '/prescriptions/',
      buildPrescriptionBody(payload),
    )
    return parsePrescription(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de creer l ordonnance.'),
      {
        cause: error,
      },
    )
  }
}

export async function createPrescriptionWithItems(
  payload: PrescriptionWithItemsPayload,
): Promise<PrescriptionWithItemsResult> {
  try {
    const response = await axiosClient.post<unknown>('/prescriptions/with-items', {
      ...buildPrescriptionBody(payload),
      medications: payload.medications.map(buildPrescriptionMedicationBody),
    })

    if (!isRecord(response.data)) {
      throw new Error('Format de reponse ordonnance invalide.')
    }

    const prescription = parsePrescription(response.data.prescription)
    const medications = parseArray(
      response.data.medications,
      parseMedication,
      'Format de reponse medicaments ordonnance invalide.',
    )
    return { prescription, medications }
  } catch (error) {
    if (isApiError(error) && (error.status === 404 || error.status === 405)) {
      const prescription = await createPrescription(payload)
      const medications: PatientMedication[] = []

      for (const item of payload.medications) {
        const createdMedication = await createMedication({
          patientId: payload.patientId,
          doctorId: payload.doctorId,
          prescriptionId: prescription.id,
          name: item.name,
          dosage: item.dosage,
          form: item.form,
          quantity: item.quantity,
          frequency: item.frequency,
          period: item.period,
          startDate: item.start_date,
          endDate: item.end_date,
          instructions: item.instructions,
        })
        medications.push(createdMedication)
      }

      return {
        prescription,
        medications,
      }
    }

    throw new Error(
      resolveErrorMessage(
        error,
        'Impossible de creer l ordonnance avec medicaments.',
      ),
      {
        cause: error,
      },
    )
  }
}

export async function getPatientAppointments(
  patientId: number,
): Promise<PatientAppointment[]> {
  try {
    const response = await axiosClient.get<unknown>(
      `/patients/${patientId}/appointments`,
    )
    const items = parseArray(
      response.data,
      parseAppointment,
      'Format de reponse rendez-vous invalide.',
    )
    return items.sort((a, b) => {
      return b.appointment_date.localeCompare(a.appointment_date)
    })
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Chargement rendez-vous impossible.'),
      {
        cause: error,
      },
    )
  }
}

export async function createAppointment(
  payload: AppointmentMutationPayload,
): Promise<PatientAppointment> {
  try {
    const response = await axiosClient.post<unknown>(
      '/appointments/',
      buildAppointmentBody(payload),
    )
    return parseAppointment(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de creer le rendez-vous.'),
      {
        cause: error,
      },
    )
  }
}

export async function updateAppointment(
  payload: AppointmentUpdatePayload,
): Promise<PatientAppointment> {
  try {
    const response = await axiosClient.put<unknown>(
      `/appointments/${payload.appointmentId}`,
      buildAppointmentBody(payload),
    )
    return parseAppointment(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de modifier le rendez-vous.'),
      {
        cause: error,
      },
    )
  }
}

export async function markAppointmentCompleted({
  appointment,
  doctorId,
}: MarkAppointmentCompletedPayload): Promise<PatientAppointment> {
  try {
    const response = await axiosClient.patch<unknown>(
      `/appointments/${appointment.id}/complete`,
      {},
    )
    return parseAppointment(response.data)
  } catch (error) {
    if (isApiError(error) && error.status === 404) {
      return updateAppointment({
        appointmentId: appointment.id,
        patientId: appointment.patient_id,
        doctorId,
        appointmentDate: appointment.appointment_date,
        notes: appointment.notes,
        status: 'done',
      })
    }

    throw new Error(
      resolveErrorMessage(error, 'Impossible de marquer le rendez-vous termine.'),
      {
        cause: error,
      },
    )
  }
}

export async function deleteAppointment(appointmentId: number): Promise<void> {
  try {
    await axiosClient.delete(`/appointments/${appointmentId}`)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de supprimer le rendez-vous.'),
      {
        cause: error,
      },
    )
  }
}

export async function getPatientActiveMedications(
  patientId: number,
): Promise<ActiveMedication[]> {
  try {
    const response = await axiosClient.get<unknown>(
      `/patients/${patientId}/active-medications`,
    )
    const items = parseArray(
      response.data,
      parseMedication,
      'Format de reponse medicaments invalide.',
    )
    return items.sort((a, b) => {
      const left = a.start_date ?? ''
      const right = b.start_date ?? ''
      return right.localeCompare(left)
    })
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Chargement medicaments actifs impossible.'),
      {
        cause: error,
      },
    )
  }
}

export async function getPatientCompletedMedications(
  patientId: number,
): Promise<PatientMedication[]> {
  try {
    const response = await axiosClient.get<unknown>(
      `/patients/${patientId}/completed-medications`,
    )
    const items = parseArray(
      response.data,
      parseMedication,
      'Format de reponse medicaments termines invalide.',
    )
    return items.sort((a, b) => {
      const left = a.start_date ?? ''
      const right = b.start_date ?? ''
      return right.localeCompare(left)
    })
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Chargement medicaments termines impossible.'),
      {
        cause: error,
      },
    )
  }
}

export async function getPatientMedications(
  patientId: number,
): Promise<PatientMedication[]> {
  try {
    const response = await axiosClient.get<unknown>(
      `/patients/${patientId}/medications`,
    )
    const items = parseArray(
      response.data,
      parseMedication,
      'Format de reponse medicaments invalide.',
    )
    return items.sort((a, b) => {
      const left = a.start_date ?? ''
      const right = b.start_date ?? ''
      return right.localeCompare(left)
    })
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Chargement liste medicaments impossible.'),
      {
        cause: error,
      },
    )
  }
}

export async function createMedication(
  payload: MedicationMutationPayload,
): Promise<PatientMedication> {
  try {
    const response = await axiosClient.post<unknown>('/medications/', {
      ...buildMedicationBody(payload),
      status: 'active',
    })
    return parseMedication(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de creer le traitement.'),
      {
        cause: error,
      },
    )
  }
}

export async function updateMedication(
  payload: MedicationUpdatePayload,
): Promise<PatientMedication> {
  try {
    const response = await axiosClient.put<unknown>(
      `/medications/${payload.medicationId}`,
      buildMedicationBody(payload),
    )
    return parseMedication(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de modifier le traitement.'),
      {
        cause: error,
      },
    )
  }
}

export async function markMedicationCompleted(
  medicationId: number,
): Promise<PatientMedication> {
  try {
    const response = await axiosClient.patch<unknown>(
      `/medications/${medicationId}/complete`,
      {},
    )
    return parseMedication(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de marquer ce traitement termine.'),
      {
        cause: error,
      },
    )
  }
}

export async function stopMedication(
  medicationId: number,
): Promise<PatientMedication> {
  try {
    const response = await axiosClient.patch<unknown>(
      `/medications/${medicationId}/stop`,
      {},
    )
    return parseMedication(response.data)
  } catch (error) {
    if (isApiError(error) && error.status === 404) {
      try {
        const fallbackResponse = await axiosClient.patch<unknown>(
          `/medications/${medicationId}/cancel`,
          {},
        )
        return parseMedication(fallbackResponse.data)
      } catch (fallbackError) {
        throw new Error(
          resolveErrorMessage(fallbackError, 'Impossible d arreter ce traitement.'),
          {
            cause: fallbackError,
          },
        )
      }
    }

    throw new Error(
      resolveErrorMessage(error, 'Impossible d arreter ce traitement.'),
      {
        cause: error,
      },
    )
  }
}

export async function deleteMedication(medicationId: number): Promise<void> {
  try {
    await axiosClient.delete(`/medications/${medicationId}`)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de supprimer ce traitement.'),
      {
        cause: error,
      },
    )
  }
}

export async function createMedicationIntake({
  medicationId,
  status,
}: MedicationIntakeCreatePayload): Promise<void> {
  try {
    await axiosClient.post('/medication-intakes/', {
      medication_id: medicationId,
      status,
      taken_at: new Date().toISOString(),
    })
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible d enregistrer cette prise.'),
      {
        cause: error,
      },
    )
  }
}

export async function getPatientDiagnoses(
  patientId: number,
): Promise<Diagnosis[]> {
  try {
    const response = await axiosClient.get<unknown>(
      `/patients/${patientId}/diagnoses`,
    )
    const items = parseArray(
      response.data,
      parseDiagnosis,
      'Format de reponse diagnostics invalide.',
    )
    return items.sort((a, b) => {
      const left = a.created_at ?? ''
      const right = b.created_at ?? ''
      return right.localeCompare(left)
    })
  } catch (error) {
    throw new Error(resolveErrorMessage(error, 'Chargement diagnostics impossible.'), {
      cause: error,
    })
  }
}

export async function getPatientMedicalNotes(
  patientId: number,
): Promise<MedicalNote[]> {
  try {
    const response = await axiosClient.get<unknown>(
      `/patients/${patientId}/medical-notes`,
    )
    const items = parseArray(
      response.data,
      parseMedicalNote,
      'Format de reponse notes medicales invalide.',
    )
    return items.sort((a, b) => {
      const left = a.created_at ?? ''
      const right = b.created_at ?? ''
      return right.localeCompare(left)
    })
  } catch (error) {
    throw new Error(resolveErrorMessage(error, 'Chargement notes impossible.'), {
      cause: error,
    })
  }
}

export async function getPatientAllergies(
  patientId: number,
): Promise<PatientAllergy[]> {
  try {
    const response = await axiosClient.get<unknown>(
      `/patients/${patientId}/allergies`,
    )
    const items = parseArray(
      response.data,
      parsePatientAllergy,
      'Format de reponse allergies invalide.',
    )
    return items.sort((a, b) => {
      const left = a.created_at ?? ''
      const right = b.created_at ?? ''
      return right.localeCompare(left)
    })
  } catch (error) {
    throw new Error(resolveErrorMessage(error, 'Chargement allergies impossible.'), {
      cause: error,
    })
  }
}

export async function createPatientAllergy(
  patientId: number,
  payload: PatientAllergyCreatePayload,
): Promise<PatientAllergy> {
  try {
    const response = await axiosClient.post<unknown>(
      `/patients/${patientId}/allergies`,
      {
        allergen: payload.allergen.trim(),
        reaction: normalizeOptionalText(payload.reaction),
        severity: normalizeAllergySeverity(payload.severity),
        notes: normalizeOptionalText(payload.notes),
      },
    )
    return parsePatientAllergy(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible d ajouter cette allergie.'),
      {
        cause: error,
      },
    )
  }
}

export async function getPatientLastLocation(
  patientId: number,
): Promise<PatientLocation | null> {
  try {
    const response = await axiosClient.get<unknown>(
      `/patients/${patientId}/last-location`,
    )
    return parsePatientLocation(response.data)
  } catch (error) {
    if (isApiError(error) && error.status === 404) {
      return null
    }
    throw new Error(
      resolveErrorMessage(error, 'Chargement localisation impossible.'),
      {
        cause: error,
      },
    )
  }
}

export async function getPatientAlerts(
  patientId: number,
): Promise<PatientAlert[]> {
  try {
    const response = await axiosClient.get<unknown>(`/patients/${patientId}/alerts`)
    const items = parseArray(
      response.data,
      parsePatientAlert,
      'Format de reponse alertes invalide.',
    )
    return items.sort((a, b) => {
      const left = a.created_at ?? ''
      const right = b.created_at ?? ''
      return right.localeCompare(left)
    })
  } catch (error) {
    throw new Error(resolveErrorMessage(error, 'Chargement alertes impossible.'), {
      cause: error,
    })
  }
}

export async function markAlertRead(alertId: number): Promise<PatientAlert> {
  try {
    const response = await axiosClient.patch<unknown>(`/alerts/${alertId}/read`, {})
    return parsePatientAlert(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de marquer l alerte comme lue.'),
      {
        cause: error,
      },
    )
  }
}
