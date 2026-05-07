import {
  type FormEvent,
  type ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from 'react'
import { Link, useParams } from 'react-router-dom'

import { useAuth } from '../../../core/auth/useAuth'
import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { EmptyState } from '../../../shared/ui/EmptyState'
import { SectionCard } from '../../../shared/ui/SectionCard'
import { StatusBadge } from '../../../shared/ui/StatusBadge'
import {
  createPatientAllergy,
  createPrescriptionWithItems,
  createMedication,
  createMedicationIntake,
  createAppointment,
  deleteMedication,
  deleteAppointment,
  getPatientActiveMedications,
  getPatientAllergies,
  getPatientAppointments,
  getPatientAlerts,
  getPatientById,
  getPatientCompletedMedications,
  getPatientDiagnoses,
  getPatientDoctors,
  getPatientLastLocation,
  getPatientPrescriptions,
  getPatientMedications,
  getPatientMedicalNotes,
  getPrescriptionById,
  markAlertRead,
  markMedicationCompleted,
  markAppointmentCompleted,
  stopMedication,
  updateMedication,
  updateAppointment,
} from '../api/patientsApi'
import {
  AllergyFormDialog,
  type AllergyFormValues,
} from '../components/AllergyFormDialog'
import { PatientAiResultsCard } from '../components/PatientAiResultsCard'
import {
  PrescriptionDetailsDialog,
} from '../components/PrescriptionDetailsDialog'
import {
  PrescriptionFormDialog,
  type PrescriptionFormValues,
} from '../components/PrescriptionFormDialog'
import type {
  ActiveMedication,
  PatientAllergy,
  PatientAlert,
  AppointmentStatus,
  Diagnosis,
  MedicationFormData,
  MedicalNote,
  PatientLocation,
  PatientMedication,
  PatientDoctorSummary,
  Patient,
  PatientAppointment,
  Prescription,
  PrescriptionDetail,
  PrescriptionItem,
  PatientStatus,
} from '../types'
import { printPrescription } from '../utils/printPrescription'

interface SectionState<T> {
  isLoading: boolean
  error: string | null
  items: T[]
}

interface LoadSectionParams<T> {
  fetcher: () => Promise<T[]>
  fallbackMessage: string
  setState: (next: SectionState<T>) => void
  isCancelled: () => boolean
}

interface SectionRendererProps<T> {
  state: SectionState<T>
  emptyTitle: string
  emptyMessage: string
  renderItem: (item: T) => ReactNode
  getKey: (item: T) => string
}

interface LocationState {
  isLoading: boolean
  error: string | null
  location: PatientLocation | null
}

interface ActionFeedback {
  type: 'success' | 'error'
  message: string
}

type AppointmentDialogMode = 'create' | 'edit'

interface AppointmentDialogState {
  isOpen: boolean
  mode: AppointmentDialogMode
  appointment: PatientAppointment | null
}

interface DeleteDialogState {
  isOpen: boolean
  appointment: PatientAppointment | null
}

type MedicationDialogMode = 'create' | 'edit'

interface MedicationDialogState {
  isOpen: boolean
  mode: MedicationDialogMode
  medication: PatientMedication | null
}

type MedicationConfirmationAction = 'stop' | 'delete'

interface MedicationConfirmationDialogState {
  isOpen: boolean
  medication: PatientMedication | null
  action: MedicationConfirmationAction
}

interface AppointmentFormValues {
  date: string
  time: string
  notes: string
  status: AppointmentStatus
}

interface AppointmentFormDialogProps {
  isOpen: boolean
  isSubmitting: boolean
  mode: AppointmentDialogMode
  patientName: string
  initialAppointment: PatientAppointment | null
  onClose: () => void
  onSubmit: (values: AppointmentFormValues) => Promise<void>
}

interface MedicationFormValues {
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

interface MedicationFormDialogProps {
  isOpen: boolean
  isSubmitting: boolean
  mode: MedicationDialogMode
  patientName: string
  initialMedication: PatientMedication | null
  onClose: () => void
  onSubmit: (values: MedicationFormValues) => Promise<void>
}

interface PrescriptionDetailsState {
  isOpen: boolean
  detail: PrescriptionDetail | null
}

interface ConfirmationDialogProps {
  isOpen: boolean
  isSubmitting: boolean
  title: string
  message: string
  confirmLabel: string
  submittingLabel?: string
  onCancel: () => void
  onConfirm: () => Promise<void>
}

const CLOSED_APPOINTMENT_DIALOG: AppointmentDialogState = {
  isOpen: false,
  mode: 'create',
  appointment: null,
}

const CLOSED_DELETE_DIALOG: DeleteDialogState = {
  isOpen: false,
  appointment: null,
}

const CLOSED_MEDICATION_DIALOG: MedicationDialogState = {
  isOpen: false,
  mode: 'create',
  medication: null,
}

const CLOSED_MEDICATION_CONFIRM_DIALOG: MedicationConfirmationDialogState = {
  isOpen: false,
  medication: null,
  action: 'stop',
}

const CLOSED_PRESCRIPTION_DETAILS_DIALOG: PrescriptionDetailsState = {
  isOpen: false,
  detail: null,
}

function createInitialSectionState<T>(): SectionState<T> {
  return {
    isLoading: false,
    error: null,
    items: [],
  }
}

function createInitialLocationState(): LocationState {
  return {
    isLoading: false,
    error: null,
    location: null,
  }
}

function createLoadingLocationState(): LocationState {
  return {
    isLoading: true,
    error: null,
    location: null,
  }
}

function createLoadingSectionState<T>(): SectionState<T> {
  return {
    isLoading: true,
    error: null,
    items: [],
  }
}

function createLoadedSectionState<T>(items: T[]): SectionState<T> {
  return {
    isLoading: false,
    error: null,
    items,
  }
}

async function loadSection<T>({
  fetcher,
  fallbackMessage,
  setState,
  isCancelled,
}: LoadSectionParams<T>): Promise<void> {
  try {
    const items = await fetcher()
    if (!isCancelled()) {
      setState(createLoadedSectionState(items))
    }
  } catch (error) {
    if (!isCancelled()) {
      setState({
        isLoading: false,
        error: error instanceof Error ? error.message : fallbackMessage,
        items: [],
      })
    }
  }
}

function parsePatientIdParam(value: string | undefined): number | null {
  if (!value) return null
  const parsed = Number.parseInt(value, 10)
  if (!Number.isFinite(parsed)) return null
  return parsed
}

function formatDateOnly(value: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
  if (match) {
    return `${match[3]}/${match[2]}/${match[1]}`
  }
  return value
}

function formatDateOnlyNullable(value: string | null): string | null {
  if (!value) return null
  return formatDateOnly(value)
}

function formatDateTime(value: string | null): string {
  if (!value) {
    return 'Non disponible'
  }

  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return value
  }

  return parsed.toLocaleString('fr-FR')
}

function getAgeFromBirthDate(birthDate: string): number {
  const parsed = new Date(birthDate)
  if (Number.isNaN(parsed.getTime())) {
    return 0
  }

  const now = new Date()
  let age = now.getFullYear() - parsed.getFullYear()
  const hasBirthdayPassed =
    now.getMonth() > parsed.getMonth() ||
    (now.getMonth() === parsed.getMonth() &&
      now.getDate() >= parsed.getDate())
  if (!hasBirthdayPassed) {
    age -= 1
  }
  return age < 0 ? 0 : age
}

function joinNonEmpty(
  values: Array<string | null | undefined>,
  separator = ' - ',
): string {
  return values.filter((value): value is string => Boolean(value)).join(separator)
}

function normalizePatientStatus(status: Patient['status']): PatientStatus | null {
  if (status === 'suivi' || status === 'nouveau' || status === 'a_verifier') {
    return status
  }
  return null
}

function resolvePatientStatus(
  status: Patient['status'],
  appointmentCount: number,
): PatientStatus {
  const normalized = normalizePatientStatus(status)
  if (normalized) {
    return normalized
  }
  return appointmentCount >= 2 ? 'suivi' : 'nouveau'
}

function getPatientStatusLabel(status: PatientStatus): string {
  if (status === 'suivi') return 'Suivi'
  if (status === 'nouveau') return 'Nouveau'
  return 'A verifier'
}

function getPatientStatusTone(status: PatientStatus): 'neutral' | 'primary' | 'warning' {
  if (status === 'suivi') return 'neutral'
  if (status === 'nouveau') return 'primary'
  return 'warning'
}

function normalizeAppointmentStatus(status: string): AppointmentStatus {
  const normalized = status.trim().toLowerCase()
  if (normalized === 'done' || normalized === 'completed') return 'done'
  if (normalized === 'cancelled' || normalized === 'canceled') {
    return 'cancelled'
  }
  if (normalized === 'missed') return 'missed'
  return 'scheduled'
}

function getEffectiveAppointmentStatus(
  appointment: PatientAppointment,
): AppointmentStatus {
  const normalizedStatus = normalizeAppointmentStatus(appointment.status)
  if (
    normalizedStatus === 'done' ||
    normalizedStatus === 'cancelled' ||
    normalizedStatus === 'missed'
  ) {
    return normalizedStatus
  }

  const date = new Date(appointment.appointment_date)
  if (Number.isNaN(date.getTime())) {
    return 'scheduled'
  }

  const missedThreshold = new Date(date.getTime() + 24 * 60 * 60 * 1000)
  if (Date.now() >= missedThreshold.getTime()) {
    return 'missed'
  }

  return 'scheduled'
}

function canMarkAppointmentCompleted(appointment: PatientAppointment): boolean {
  const effectiveStatus = getEffectiveAppointmentStatus(appointment)
  return effectiveStatus === 'scheduled' || effectiveStatus === 'missed'
}

function formatAppointmentStatus(status: AppointmentStatus): string {
  if (status === 'done') return 'Termine'
  if (status === 'cancelled') return 'Annule'
  if (status === 'missed') return 'Manque'
  return 'Planifie'
}

function getAppointmentTone(
  status: AppointmentStatus,
): 'primary' | 'success' | 'warning' | 'danger' {
  if (status === 'done') return 'success'
  if (status === 'cancelled') return 'warning'
  if (status === 'missed') return 'danger'
  return 'primary'
}

function normalizeMedicationStatus(status: string): PatientMedication['status'] {
  const normalized = status.trim().toLowerCase()
  if (normalized === 'completed' || normalized === 'done') return 'completed'
  if (
    normalized === 'stopped' ||
    normalized === 'stop' ||
    normalized === 'cancelled' ||
    normalized === 'canceled' ||
    normalized === 'cancel'
  ) {
    return 'stopped'
  }
  return 'active'
}

function formatMedicationStatus(status: string): string {
  const normalizedStatus = normalizeMedicationStatus(status)
  if (normalizedStatus === 'completed') return 'Termine'
  if (normalizedStatus === 'stopped') return 'Arrete'
  return 'Actif'
}

function getMedicationTone(status: string): 'primary' | 'success' | 'warning' {
  const normalizedStatus = normalizeMedicationStatus(status)
  if (normalizedStatus === 'completed') return 'success'
  if (normalizedStatus === 'stopped') return 'warning'
  return 'primary'
}

function normalizePrescriptionStatus(status: string): Prescription['status'] {
  const normalized = status.trim().toLowerCase()
  if (normalized === 'completed' || normalized === 'done' || normalized === 'terminee') {
    return 'completed'
  }
  if (
    normalized === 'cancelled' ||
    normalized === 'canceled' ||
    normalized === 'cancel' ||
    normalized === 'annulee'
  ) {
    return 'cancelled'
  }
  return 'active'
}

function formatPrescriptionStatus(status: string): string {
  const normalized = normalizePrescriptionStatus(status)
  if (normalized === 'completed') return 'Terminee'
  if (normalized === 'cancelled') return 'Annulee'
  return 'Active'
}

function getPrescriptionTone(
  status: string,
): 'primary' | 'success' | 'warning' {
  const normalized = normalizePrescriptionStatus(status)
  if (normalized === 'completed') return 'success'
  if (normalized === 'cancelled') return 'warning'
  return 'primary'
}

function mapMedicationFormDataToPrescriptionItem(
  medication: MedicationFormData,
): PrescriptionItem {
  return {
    name: medication.name.trim(),
    dosage: medication.dosage.trim(),
    form: medication.form.trim() || null,
    quantity: medication.quantity.trim(),
    frequency: medication.frequency.trim(),
    period: medication.period.trim(),
    start_date: medication.startDate,
    end_date: medication.endDate.trim() || null,
    instructions: medication.instructions.trim(),
  }
}

function normalizeAlertType(type: string): string {
  return type.trim().toLowerCase()
}

function getAlertTypeLabel(type: string): string {
  const normalizedType = normalizeAlertType(type)
  if (
    normalizedType === 'geofence_exit' ||
    normalizedType === 'safe_zone_exit' ||
    normalizedType === 'location_outside_safe_zone'
  ) {
    return 'Localisation'
  }
  if (normalizedType === 'medication' || normalizedType === 'medication_missed') {
    return 'Medicament'
  }
  if (normalizedType === 'appointment') {
    return 'Rendez-vous'
  }
  if (normalizedType === 'emergency') {
    return 'Urgence'
  }
  if (normalizedType === 'warning') {
    return 'Avertissement'
  }
  return 'Information'
}

function getAlertTypeTone(type: string): 'neutral' | 'primary' | 'warning' | 'danger' {
  const normalizedType = normalizeAlertType(type)
  if (
    normalizedType === 'geofence_exit' ||
    normalizedType === 'safe_zone_exit' ||
    normalizedType === 'location_outside_safe_zone' ||
    normalizedType === 'emergency'
  ) {
    return 'danger'
  }
  if (normalizedType === 'medication' || normalizedType === 'medication_missed') {
    return 'warning'
  }
  if (normalizedType === 'appointment') {
    return 'primary'
  }
  return 'neutral'
}

function getAlertReadTone(isRead: boolean): 'success' | 'warning' {
  return isRead ? 'success' : 'warning'
}

function normalizeAllergySeverity(severity: string): PatientAllergy['severity'] {
  const normalized = severity.trim().toLowerCase()
  if (normalized === 'low') return 'low'
  if (normalized === 'high') return 'high'
  if (normalized === 'critical') return 'critical'
  return 'moderate'
}

function getAllergySeverityLabel(severity: string): string {
  const normalizedSeverity = normalizeAllergySeverity(severity)
  if (normalizedSeverity === 'low') return 'Faible'
  if (normalizedSeverity === 'high') return 'Elevee'
  if (normalizedSeverity === 'critical') return 'Critique'
  return 'Moderee'
}

function getAllergySeverityTone(
  severity: string,
): 'success' | 'primary' | 'warning' | 'danger' {
  const normalizedSeverity = normalizeAllergySeverity(severity)
  if (normalizedSeverity === 'low') return 'success'
  if (normalizedSeverity === 'high') return 'warning'
  if (normalizedSeverity === 'critical') return 'danger'
  return 'primary'
}

function formatCoordinates(latitude: number, longitude: number): string {
  return `${latitude.toFixed(6)}, ${longitude.toFixed(6)}`
}

function isMedicationActive(medication: PatientMedication): boolean {
  if (normalizeMedicationStatus(medication.status) !== 'active') {
    return false
  }

  if (!medication.end_date) {
    return true
  }

  const endDate = new Date(medication.end_date)
  if (Number.isNaN(endDate.getTime())) {
    return true
  }

  const today = new Date()
  const normalizedToday = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate(),
  )
  const normalizedEndDate = new Date(
    endDate.getFullYear(),
    endDate.getMonth(),
    endDate.getDate(),
  )
  return normalizedEndDate.getTime() >= normalizedToday.getTime()
}

function toDateInputValue(value: string | null): string {
  if (!value) {
    return ''
  }

  const match = /^(\d{4}-\d{2}-\d{2})/.exec(value)
  if (match) {
    return match[1]
  }

  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return ''
  }

  return formatDateInput(parsed)
}

function sortMedicationsByStartDate(
  medications: PatientMedication[],
): PatientMedication[] {
  return [...medications].sort((left, right) => {
    const leftValue = left.start_date ?? ''
    const rightValue = right.start_date ?? ''
    return rightValue.localeCompare(leftValue)
  })
}

function mergeArchivedMedications(
  completedMedications: PatientMedication[],
  allMedications: PatientMedication[],
): PatientMedication[] {
  const byId = new Map<number, PatientMedication>()

  for (const item of completedMedications) {
    byId.set(item.id, item)
  }

  for (const item of allMedications) {
    if (normalizeMedicationStatus(item.status) === 'stopped') {
      byId.set(item.id, item)
    }
  }

  return sortMedicationsByStartDate(Array.from(byId.values()))
}

function getActionErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return fallback
}

function formatDateInput(date: Date): string {
  const year = date.getFullYear().toString().padStart(4, '0')
  const month = `${date.getMonth() + 1}`.padStart(2, '0')
  const day = `${date.getDate()}`.padStart(2, '0')
  return `${year}-${month}-${day}`
}

function formatTimeInput(date: Date): string {
  const hours = `${date.getHours()}`.padStart(2, '0')
  const minutes = `${date.getMinutes()}`.padStart(2, '0')
  return `${hours}:${minutes}`
}

function getDateTimeFormParts(value: string): { date: string; time: string } {
  const parsed = new Date(value)
  if (!Number.isNaN(parsed.getTime())) {
    return {
      date: formatDateInput(parsed),
      time: formatTimeInput(parsed),
    }
  }

  const match = /^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})/.exec(value)
  if (match) {
    return { date: match[1], time: match[2] }
  }

  return { date: '', time: '' }
}

function buildAppointmentDateTimeForApi(date: string, time: string): string {
  return `${date}T${time}:00`
}

function SectionRenderer<T>({
  state,
  emptyTitle,
  emptyMessage,
  renderItem,
  getKey,
}: SectionRendererProps<T>) {
  if (state.isLoading) {
    return <p className="state-text">Chargement...</p>
  }

  if (state.error) {
    return (
      <EmptyState
        iconLabel="ERR"
        message={state.error}
        title="Chargement impossible"
      />
    )
  }

  if (state.items.length === 0) {
    return (
      <EmptyState
        iconLabel="VIDE"
        message={emptyMessage}
        title={emptyTitle}
      />
    )
  }

  return (
    <div className="record-list">
      {state.items.map((item) => (
        <article className="record-card" key={getKey(item)}>
          {renderItem(item)}
        </article>
      ))}
    </div>
  )
}

function AppointmentFormDialog({
  isOpen,
  isSubmitting,
  mode,
  patientName,
  initialAppointment,
  onClose,
  onSubmit,
}: AppointmentFormDialogProps) {
  const initialValues = useMemo<AppointmentFormValues>(() => {
    if (mode === 'edit' && initialAppointment) {
      const values = getDateTimeFormParts(initialAppointment.appointment_date)
      return {
        date: values.date,
        time: values.time,
        notes: initialAppointment.notes ?? '',
        status: normalizeAppointmentStatus(initialAppointment.status),
      }
    }

    return {
      date: '',
      time: '',
      notes: '',
      status: 'scheduled',
    }
  }, [initialAppointment, mode])

  const [dateValue, setDateValue] = useState(initialValues.date)
  const [timeValue, setTimeValue] = useState(initialValues.time)
  const [notes, setNotes] = useState(initialValues.notes)
  const [status, setStatus] = useState<AppointmentStatus>(initialValues.status)
  const [formError, setFormError] = useState<string | null>(null)

  if (!isOpen) {
    return null
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFormError(null)

    if (!dateValue || !timeValue) {
      setFormError('Date et heure obligatoires.')
      return
    }

    await onSubmit({
      date: dateValue,
      time: timeValue,
      notes,
      status,
    })
  }

  const title = mode === 'edit' ? 'Modifier rendez-vous' : 'Ajouter rendez-vous'
  const submitLabel = mode === 'edit' ? 'Enregistrer' : 'Ajouter rendez-vous'

  return (
    <div aria-modal className="dialog-overlay" role="dialog">
      <div className="dialog-card">
        <header className="dialog-header">
          <h4>{title}</h4>
          <p>Pour {patientName}</p>
        </header>

        {formError && (
          <div className="feedback-banner is-error" role="alert">
            {formError}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="dialog-grid">
            <label className="field-block">
              <span>Date</span>
              <input
                className="input-control"
                onChange={(event) => setDateValue(event.target.value)}
                type="date"
                value={dateValue}
              />
            </label>

            <label className="field-block">
              <span>Heure</span>
              <input
                className="input-control"
                onChange={(event) => setTimeValue(event.target.value)}
                type="time"
                value={timeValue}
              />
            </label>

            {mode === 'edit' && (
              <label className="field-block full">
                <span>Statut</span>
                <select
                  className="input-control"
                  onChange={(event) => {
                    setStatus(event.target.value as AppointmentStatus)
                  }}
                  value={status}
                >
                  <option value="scheduled">Planifie</option>
                  <option value="done">Termine</option>
                  <option value="cancelled">Annule</option>
                  <option value="missed">Manque</option>
                </select>
              </label>
            )}

            <label className="field-block full">
              <span>Notes (optionnel)</span>
              <textarea
                className="input-control"
                onChange={(event) => setNotes(event.target.value)}
                rows={4}
                value={notes}
              />
            </label>
          </div>

          <div className="dialog-actions">
            <button
              className="btn btn-outline"
              disabled={isSubmitting}
              onClick={onClose}
              type="button"
            >
              Annuler
            </button>
            <button className="btn btn-primary" disabled={isSubmitting} type="submit">
              {isSubmitting ? 'Enregistrement...' : submitLabel}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function MedicationFormDialog({
  isOpen,
  isSubmitting,
  mode,
  patientName,
  initialMedication,
  onClose,
  onSubmit,
}: MedicationFormDialogProps) {
  const initialValues = useMemo<MedicationFormValues>(() => {
    if (mode === 'edit' && initialMedication) {
      return {
        name: initialMedication.name,
        dosage: initialMedication.dosage ?? '',
        form: initialMedication.form ?? '',
        quantity: initialMedication.quantity ?? '',
        frequency: initialMedication.frequency ?? '',
        period: initialMedication.period ?? '',
        startDate: toDateInputValue(initialMedication.start_date),
        endDate: toDateInputValue(initialMedication.end_date),
        instructions: initialMedication.instructions ?? '',
      }
    }

    return {
      name: '',
      dosage: '',
      form: '',
      quantity: '',
      frequency: '',
      period: '',
      startDate: '',
      endDate: '',
      instructions: '',
    }
  }, [initialMedication, mode])

  const [name, setName] = useState(initialValues.name)
  const [dosage, setDosage] = useState(initialValues.dosage)
  const [form, setForm] = useState(initialValues.form)
  const [quantity, setQuantity] = useState(initialValues.quantity)
  const [frequency, setFrequency] = useState(initialValues.frequency)
  const [period, setPeriod] = useState(initialValues.period)
  const [startDate, setStartDate] = useState(initialValues.startDate)
  const [endDate, setEndDate] = useState(initialValues.endDate)
  const [instructions, setInstructions] = useState(initialValues.instructions)
  const [formError, setFormError] = useState<string | null>(null)

  if (!isOpen) {
    return null
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFormError(null)

    if (
      !name.trim() ||
      !dosage.trim() ||
      !quantity.trim() ||
      !frequency.trim() ||
      !period.trim() ||
      !startDate.trim() ||
      !instructions.trim()
    ) {
      setFormError('Veuillez remplir tous les champs obligatoires.')
      return
    }

    if (endDate && endDate < startDate) {
      setFormError('Date de fin >= date de debut.')
      return
    }

    await onSubmit({
      name,
      dosage,
      form,
      quantity,
      frequency,
      period,
      startDate,
      endDate,
      instructions,
    })
  }

  const title = mode === 'edit' ? 'Modifier traitement' : 'Ajouter traitement'
  const submitLabel = mode === 'edit' ? 'Enregistrer' : 'Ajouter traitement'

  return (
    <div aria-modal className="dialog-overlay" role="dialog">
      <div className="dialog-card">
        <header className="dialog-header">
          <h4>{title}</h4>
          <p>Pour {patientName}</p>
        </header>

        {formError && (
          <div className="feedback-banner is-error" role="alert">
            {formError}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="dialog-grid">
            <label className="field-block">
              <span>Nom du medicament</span>
              <input
                className="input-control"
                onChange={(event) => setName(event.target.value)}
                value={name}
              />
            </label>

            <label className="field-block">
              <span>Dosage</span>
              <input
                className="input-control"
                onChange={(event) => setDosage(event.target.value)}
                value={dosage}
              />
            </label>

            <label className="field-block">
              <span>Forme (optionnel)</span>
              <input
                className="input-control"
                onChange={(event) => setForm(event.target.value)}
                value={form}
              />
            </label>

            <label className="field-block">
              <span>Quantite</span>
              <input
                className="input-control"
                onChange={(event) => setQuantity(event.target.value)}
                value={quantity}
              />
            </label>

            <label className="field-block">
              <span>Frequence</span>
              <input
                className="input-control"
                onChange={(event) => setFrequency(event.target.value)}
                value={frequency}
              />
            </label>

            <label className="field-block">
              <span>Periode / duree</span>
              <input
                className="input-control"
                onChange={(event) => setPeriod(event.target.value)}
                value={period}
              />
            </label>

            <label className="field-block">
              <span>Date debut</span>
              <input
                className="input-control"
                onChange={(event) => setStartDate(event.target.value)}
                type="date"
                value={startDate}
              />
            </label>

            <label className="field-block">
              <span>Date fin (optionnel)</span>
              <input
                className="input-control"
                onChange={(event) => setEndDate(event.target.value)}
                type="date"
                value={endDate}
              />
            </label>

            <label className="field-block full">
              <span>Instructions</span>
              <textarea
                className="input-control"
                onChange={(event) => setInstructions(event.target.value)}
                rows={4}
                value={instructions}
              />
            </label>
          </div>

          <div className="dialog-actions">
            <button
              className="btn btn-outline"
              disabled={isSubmitting}
              onClick={onClose}
              type="button"
            >
              Annuler
            </button>
            <button className="btn btn-primary" disabled={isSubmitting} type="submit">
              {isSubmitting ? 'Enregistrement...' : submitLabel}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function ConfirmationDialog({
  isOpen,
  isSubmitting,
  title,
  message,
  confirmLabel,
  submittingLabel,
  onCancel,
  onConfirm,
}: ConfirmationDialogProps) {
  if (!isOpen) {
    return null
  }

  return (
    <div aria-modal className="dialog-overlay" role="dialog">
      <div className="dialog-card">
        <header className="dialog-header">
          <h4>{title}</h4>
          <p>{message}</p>
        </header>
        <div className="dialog-actions">
          <button
            className="btn btn-outline"
            disabled={isSubmitting}
            onClick={onCancel}
            type="button"
          >
            Annuler
          </button>
          <button
            className="btn btn-primary"
            disabled={isSubmitting}
            onClick={() => {
              void onConfirm()
            }}
            type="button"
          >
            {isSubmitting ? (submittingLabel ?? 'Suppression...') : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}

export function PatientDetailsPage() {
  const params = useParams()
  const { user } = useAuth()
  const [patient, setPatient] = useState<Patient | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [allMedications, setAllMedications] = useState<PatientMedication[]>([])
  const [appointmentsState, setAppointmentsState] = useState<
    SectionState<PatientAppointment>
  >(createInitialSectionState<PatientAppointment>())
  const [medicationsState, setMedicationsState] = useState<
    SectionState<ActiveMedication>
  >(createInitialSectionState<ActiveMedication>())
  const [prescriptionsState, setPrescriptionsState] = useState<
    SectionState<Prescription>
  >(createInitialSectionState<Prescription>())
  const [archivedMedicationsState, setArchivedMedicationsState] = useState<
    SectionState<PatientMedication>
  >(createInitialSectionState<PatientMedication>())
  const [locationState, setLocationState] = useState<LocationState>(
    createInitialLocationState(),
  )
  const [alertsState, setAlertsState] = useState<SectionState<PatientAlert>>(
    createInitialSectionState<PatientAlert>(),
  )
  const [diagnosesState, setDiagnosesState] = useState<
    SectionState<Diagnosis>
  >(createInitialSectionState<Diagnosis>())
  const [notesState, setNotesState] = useState<SectionState<MedicalNote>>(
    createInitialSectionState<MedicalNote>(),
  )
  const [patientDoctors, setPatientDoctors] = useState<PatientDoctorSummary[]>([])
  const [allergiesState, setAllergiesState] = useState<
    SectionState<PatientAllergy>
  >(createInitialSectionState<PatientAllergy>())
  const [appointmentDialog, setAppointmentDialog] = useState<AppointmentDialogState>(
    CLOSED_APPOINTMENT_DIALOG,
  )
  const [deleteDialog, setDeleteDialog] = useState<DeleteDialogState>(
    CLOSED_DELETE_DIALOG,
  )
  const [medicationDialog, setMedicationDialog] = useState<MedicationDialogState>(
    CLOSED_MEDICATION_DIALOG,
  )
  const [medicationConfirmationDialog, setMedicationConfirmationDialog] =
    useState<MedicationConfirmationDialogState>(CLOSED_MEDICATION_CONFIRM_DIALOG)
  const [isSubmittingAppointment, setIsSubmittingAppointment] = useState(false)
  const [isSubmittingMedication, setIsSubmittingMedication] = useState(false)
  const [pendingAppointmentId, setPendingAppointmentId] = useState<number | null>(
    null,
  )
  const [pendingMedicationId, setPendingMedicationId] = useState<number | null>(
    null,
  )
  const [pendingPrescriptionId, setPendingPrescriptionId] = useState<number | null>(
    null,
  )
  const [pendingAlertId, setPendingAlertId] = useState<number | null>(null)
  const [isSubmittingPrescription, setIsSubmittingPrescription] = useState(false)
  const [isSubmittingAllergy, setIsSubmittingAllergy] = useState(false)
  const [isPrintingPrescription, setIsPrintingPrescription] = useState(false)
  const [isPrescriptionFormOpen, setIsPrescriptionFormOpen] = useState(false)
  const [isAllergyFormOpen, setIsAllergyFormOpen] = useState(false)
  const [prescriptionDetailsDialog, setPrescriptionDetailsDialog] =
    useState<PrescriptionDetailsState>(CLOSED_PRESCRIPTION_DETAILS_DIALOG)
  const [appointmentFeedback, setAppointmentFeedback] =
    useState<ActionFeedback | null>(null)
  const [medicationFeedback, setMedicationFeedback] =
    useState<ActionFeedback | null>(null)
  const [prescriptionFeedback, setPrescriptionFeedback] =
    useState<ActionFeedback | null>(null)
  const [allergyFeedback, setAllergyFeedback] = useState<ActionFeedback | null>(
    null,
  )
  const [alertFeedback, setAlertFeedback] = useState<ActionFeedback | null>(null)

  const patientId = useMemo(() => {
    return parsePatientIdParam(params.patientId)
  }, [params.patientId])
  const isDoctor = user?.role === 'doctor'
  const isFamily = user?.role === 'family'

  const refreshAppointments = useCallback(async () => {
    if (!patientId) {
      return
    }

    setAppointmentsState(createLoadingSectionState<PatientAppointment>())
    await loadSection<PatientAppointment>({
      fetcher: () => getPatientAppointments(patientId),
      fallbackMessage: 'Impossible de charger les rendez-vous.',
      setState: setAppointmentsState,
      isCancelled: () => false,
    })
  }, [patientId])

  const refreshMedications = useCallback(async () => {
    if (!patientId) {
      return
    }

    setMedicationsState(createLoadingSectionState<ActiveMedication>())
    setArchivedMedicationsState(createLoadingSectionState<PatientMedication>())

    try {
      const [activeMedications, completedMedications, allMedications] =
        await Promise.all([
          getPatientActiveMedications(patientId),
          getPatientCompletedMedications(patientId),
          getPatientMedications(patientId),
        ])

      setAllMedications(sortMedicationsByStartDate(allMedications))
      setMedicationsState(
        createLoadedSectionState(
          sortMedicationsByStartDate(activeMedications.filter(isMedicationActive)),
        ),
      )
      setArchivedMedicationsState(
        createLoadedSectionState(
          mergeArchivedMedications(completedMedications, allMedications),
        ),
      )
    } catch (loadError) {
      const message = getActionErrorMessage(
        loadError,
        'Impossible de charger les traitements.',
      )
      setAllMedications([])
      setMedicationsState({
        isLoading: false,
        error: message,
        items: [],
      })
      setArchivedMedicationsState({
        isLoading: false,
        error: message,
        items: [],
      })
    }
  }, [patientId])

  const refreshPrescriptions = useCallback(async () => {
    if (!patientId) {
      return
    }

    setPrescriptionsState(createLoadingSectionState<Prescription>())
    await loadSection<Prescription>({
      fetcher: () => getPatientPrescriptions(patientId),
      fallbackMessage: 'Impossible de charger les ordonnances.',
      setState: setPrescriptionsState,
      isCancelled: () => false,
    })
  }, [patientId])

  const refreshAlerts = useCallback(async () => {
    if (!patientId) {
      return
    }

    setAlertsState(createLoadingSectionState<PatientAlert>())
    await loadSection<PatientAlert>({
      fetcher: () => getPatientAlerts(patientId),
      fallbackMessage: 'Impossible de charger les alertes.',
      setState: setAlertsState,
      isCancelled: () => false,
    })
  }, [patientId])

  const refreshAllergies = useCallback(async () => {
    if (!patientId) {
      return
    }

    setAllergiesState(createLoadingSectionState<PatientAllergy>())
    await loadSection<PatientAllergy>({
      fetcher: () => getPatientAllergies(patientId),
      fallbackMessage: 'Impossible de charger les allergies.',
      setState: setAllergiesState,
      isCancelled: () => false,
    })
  }, [patientId])

  useEffect(() => {
    let isCancelled = false

    async function loadPatient() {
      if (!params.patientId) {
        setError('Identifiant patient manquant.')
        setIsLoading(false)
        return
      }

      if (!patientId) {
        setError('Identifiant patient invalide.')
        setIsLoading(false)
        return
      }

      setIsLoading(true)
      setError(null)
      setAlertFeedback(null)
      setAllergyFeedback(null)
      setPendingAlertId(null)
      setIsAllergyFormOpen(false)
      setIsSubmittingAllergy(false)
      setAppointmentsState(createLoadingSectionState<PatientAppointment>())
      setMedicationsState(createLoadingSectionState<ActiveMedication>())
      setAllMedications([])
      setPrescriptionsState(createLoadingSectionState<Prescription>())
      setArchivedMedicationsState(createLoadingSectionState<PatientMedication>())
      setLocationState(createLoadingLocationState())
      setAlertsState(createLoadingSectionState<PatientAlert>())
      setDiagnosesState(createLoadingSectionState<Diagnosis>())
      setNotesState(createLoadingSectionState<MedicalNote>())
      setAllergiesState(createLoadingSectionState<PatientAllergy>())
      setPatientDoctors([])

      try {
        const patientData = await getPatientById(patientId)
        if (!isCancelled) {
          setPatient(patientData)
        }

        await Promise.all([
          loadSection<PatientAppointment>({
            fetcher: () => getPatientAppointments(patientId),
            fallbackMessage: 'Impossible de charger les rendez-vous.',
            setState: setAppointmentsState,
            isCancelled: () => isCancelled,
          }),
          (async () => {
            try {
              const [activeMedications, completedMedications, allMedications] =
                await Promise.all([
                  getPatientActiveMedications(patientId),
                  getPatientCompletedMedications(patientId),
                  getPatientMedications(patientId),
                ])

              if (!isCancelled) {
                setAllMedications(sortMedicationsByStartDate(allMedications))
                setMedicationsState(
                  createLoadedSectionState(
                    sortMedicationsByStartDate(
                      activeMedications.filter(isMedicationActive),
                    ),
                  ),
                )
                setArchivedMedicationsState(
                  createLoadedSectionState(
                    mergeArchivedMedications(
                      completedMedications,
                      allMedications,
                    ),
                  ),
                )
              }
            } catch (medicationsError) {
              if (!isCancelled) {
                const message = getActionErrorMessage(
                  medicationsError,
                  'Impossible de charger les traitements.',
                )
                setAllMedications([])
                setMedicationsState({
                  isLoading: false,
                  error: message,
                  items: [],
                })
                setArchivedMedicationsState({
                  isLoading: false,
                  error: message,
                  items: [],
                })
              }
            }
          })(),
          (async () => {
            if (isDoctor) {
              if (!isCancelled) {
                setLocationState(createInitialLocationState())
              }
              return
            }

            try {
              const location = await getPatientLastLocation(patientId)
              if (!isCancelled) {
                setLocationState({
                  isLoading: false,
                  error: null,
                  location,
                })
              }
            } catch (locationError) {
              if (!isCancelled) {
                setLocationState({
                  isLoading: false,
                  error: getActionErrorMessage(
                    locationError,
                    'Impossible de charger la localisation.',
                  ),
                  location: null,
                })
              }
            }
          })(),
          isDoctor
            ? (async () => {
                if (!isCancelled) {
                  setAlertsState(createLoadedSectionState<PatientAlert>([]))
                }
              })()
            : loadSection<PatientAlert>({
                fetcher: () => getPatientAlerts(patientId),
                fallbackMessage: 'Impossible de charger les alertes.',
                setState: setAlertsState,
                isCancelled: () => isCancelled,
              }),
          loadSection<Diagnosis>({
            fetcher: () => getPatientDiagnoses(patientId),
            fallbackMessage: 'Impossible de charger les diagnostics.',
            setState: setDiagnosesState,
            isCancelled: () => isCancelled,
          }),
          isDoctor
            ? (async () => {
                if (!isCancelled) {
                  setNotesState(createLoadedSectionState<MedicalNote>([]))
                }
              })()
            : loadSection<MedicalNote>({
                fetcher: () => getPatientMedicalNotes(patientId),
                fallbackMessage: 'Impossible de charger les notes medicales.',
                setState: setNotesState,
                isCancelled: () => isCancelled,
              }),
          loadSection<PatientAllergy>({
            fetcher: () => getPatientAllergies(patientId),
            fallbackMessage: 'Impossible de charger les allergies.',
            setState: setAllergiesState,
            isCancelled: () => isCancelled,
          }),
          (async () => {
            try {
              const doctors = await getPatientDoctors(patientId)
              if (!isCancelled) {
                setPatientDoctors(doctors)
              }
            } catch {
              if (!isCancelled) {
                setPatientDoctors([])
              }
            }
          })(),
          loadSection<Prescription>({
            fetcher: () => getPatientPrescriptions(patientId),
            fallbackMessage: 'Impossible de charger les ordonnances.',
            setState: setPrescriptionsState,
            isCancelled: () => isCancelled,
          }),
        ])
      } catch (loadError) {
        if (!isCancelled) {
          const message =
            loadError instanceof Error
              ? loadError.message
              : 'Impossible de charger le patient.'
          setError(message)
          setPatient(null)
          setAppointmentsState(createLoadedSectionState<PatientAppointment>([]))
          setMedicationsState(createLoadedSectionState<ActiveMedication>([]))
          setAllMedications([])
          setPrescriptionsState(createLoadedSectionState<Prescription>([]))
          setArchivedMedicationsState(
            createLoadedSectionState<PatientMedication>([]),
          )
          setLocationState(createInitialLocationState())
          setAlertsState(createLoadedSectionState<PatientAlert>([]))
          setDiagnosesState(createLoadedSectionState<Diagnosis>([]))
          setNotesState(createLoadedSectionState<MedicalNote>([]))
          setAllergiesState(createLoadedSectionState<PatientAllergy>([]))
          setPatientDoctors([])
        }
      } finally {
        if (!isCancelled) {
          setIsLoading(false)
        }
      }
    }

    void loadPatient()
    return () => {
      isCancelled = true
    }
  }, [isDoctor, params.patientId, patientId])

  const patientComputedStatus = useMemo(() => {
    if (!patient) {
      return 'nouveau' as PatientStatus
    }
    return resolvePatientStatus(patient.status, appointmentsState.items.length)
  }, [appointmentsState.items.length, patient])

  const medicationsByPrescriptionId = useMemo(() => {
    const map = new Map<number, PatientMedication[]>()
    for (const medication of allMedications) {
      const prescriptionId = medication.prescription_id
      if (!prescriptionId) {
        continue
      }
      const bucket = map.get(prescriptionId)
      if (bucket) {
        bucket.push(medication)
      } else {
        map.set(prescriptionId, [medication])
      }
    }
    return map
  }, [allMedications])

  const doctorNameById = useMemo(() => {
    const map = new Map<number, string>()
    for (const doctor of patientDoctors) {
      const fullName = `${doctor.first_name} ${doctor.last_name}`.trim()
      if (fullName.length > 0) {
        map.set(doctor.id, fullName)
      }
    }
    return map
  }, [patientDoctors])

  const resolvePrescriberLabel = useCallback(
    (doctorId: number): string => {
      const mappedName = doctorNameById.get(doctorId)
      if (mappedName) {
        return `Dr. ${mappedName}`.trim()
      }

      if (user && user.id === doctorId) {
        const currentUserName = `${user.first_name} ${user.last_name}`.trim()
        if (currentUserName.length > 0) {
          return `Dr. ${currentUserName}`.trim()
        }
      }

      return 'Medecin'
    },
    [doctorNameById, user],
  )

  const closeAppointmentDialog = useCallback(() => {
    if (isSubmittingAppointment) {
      return
    }
    setAppointmentDialog(CLOSED_APPOINTMENT_DIALOG)
  }, [isSubmittingAppointment])

  const closeDeleteDialog = useCallback(() => {
    if (pendingAppointmentId !== null) {
      return
    }
    setDeleteDialog(CLOSED_DELETE_DIALOG)
  }, [pendingAppointmentId])

  const closeMedicationDialog = useCallback(() => {
    if (isSubmittingMedication) {
      return
    }
    setMedicationDialog(CLOSED_MEDICATION_DIALOG)
  }, [isSubmittingMedication])

  const closeMedicationConfirmationDialog = useCallback(() => {
    if (pendingMedicationId !== null) {
      return
    }
    setMedicationConfirmationDialog(CLOSED_MEDICATION_CONFIRM_DIALOG)
  }, [pendingMedicationId])

  const closePrescriptionForm = useCallback(() => {
    if (isSubmittingPrescription) {
      return
    }
    setIsPrescriptionFormOpen(false)
  }, [isSubmittingPrescription])

  const closeAllergyForm = useCallback(() => {
    if (isSubmittingAllergy) {
      return
    }
    setIsAllergyFormOpen(false)
  }, [isSubmittingAllergy])

  const closePrescriptionDetails = useCallback(() => {
    if (isPrintingPrescription || pendingPrescriptionId !== null) {
      return
    }
    setPrescriptionDetailsDialog(CLOSED_PRESCRIPTION_DETAILS_DIALOG)
  }, [isPrintingPrescription, pendingPrescriptionId])

  const openCreateAppointmentDialog = useCallback(() => {
    if (!isDoctor) {
      return
    }
    setAppointmentFeedback(null)
    setAppointmentDialog({
      isOpen: true,
      mode: 'create',
      appointment: null,
    })
  }, [isDoctor])

  const openEditAppointmentDialog = useCallback((appointment: PatientAppointment) => {
    if (!isDoctor) {
      return
    }
    setAppointmentFeedback(null)
    setAppointmentDialog({
      isOpen: true,
      mode: 'edit',
      appointment,
    })
  }, [isDoctor])

  const openDeleteDialog = useCallback((appointment: PatientAppointment) => {
    if (!isDoctor) {
      return
    }
    setDeleteDialog({
      isOpen: true,
      appointment,
    })
  }, [isDoctor])

  const openPrescriptionForm = useCallback(() => {
    if (!isDoctor) {
      return
    }
    setPrescriptionFeedback(null)
    setIsPrescriptionFormOpen(true)
  }, [isDoctor])

  const openAllergyForm = useCallback(() => {
    if (!isDoctor) {
      return
    }
    setAllergyFeedback(null)
    setIsAllergyFormOpen(true)
  }, [isDoctor])

  const openEditMedicationDialog = useCallback((medication: PatientMedication) => {
    if (!isDoctor) {
      return
    }
    setMedicationFeedback(null)
    setMedicationDialog({
      isOpen: true,
      mode: 'edit',
      medication,
    })
  }, [isDoctor])

  const openMedicationStopDialog = useCallback((medication: PatientMedication) => {
    if (!isDoctor) {
      return
    }
    setMedicationFeedback(null)
    setMedicationConfirmationDialog({
      isOpen: true,
      medication,
      action: 'stop',
    })
  }, [isDoctor])

  const openMedicationDeleteDialog = useCallback((medication: PatientMedication) => {
    if (!isDoctor) {
      return
    }
    setMedicationFeedback(null)
    setMedicationConfirmationDialog({
      isOpen: true,
      medication,
      action: 'delete',
    })
  }, [isDoctor])

  const handleSubmitAppointment = useCallback(
    async (values: AppointmentFormValues) => {
      if (!isDoctor || !user || !patientId) {
        setAppointmentFeedback({
          type: 'error',
          message: 'Action reservee au medecin.',
        })
        return
      }

      setIsSubmittingAppointment(true)
      setAppointmentFeedback(null)
      try {
        const appointmentDate = buildAppointmentDateTimeForApi(
          values.date,
          values.time,
        )

        if (appointmentDialog.mode === 'edit' && appointmentDialog.appointment) {
          await updateAppointment({
            appointmentId: appointmentDialog.appointment.id,
            patientId,
            doctorId: user.id,
            appointmentDate,
            notes: values.notes,
            status: values.status,
          })
          setAppointmentFeedback({
            type: 'success',
            message: 'Rendez-vous modifie avec succes.',
          })
        } else {
          await createAppointment({
            patientId,
            doctorId: user.id,
            appointmentDate,
            notes: values.notes,
            status: 'scheduled',
          })
          setAppointmentFeedback({
            type: 'success',
            message: 'Rendez-vous ajoute avec succes.',
          })
        }

        setAppointmentDialog(CLOSED_APPOINTMENT_DIALOG)
        await refreshAppointments()
      } catch (submitError) {
        setAppointmentFeedback({
          type: 'error',
          message: getActionErrorMessage(
            submitError,
            appointmentDialog.mode === 'edit'
              ? 'Impossible de modifier le rendez-vous.'
              : 'Impossible de creer le rendez-vous.',
          ),
        })
      } finally {
        setIsSubmittingAppointment(false)
      }
    },
    [appointmentDialog, isDoctor, patientId, refreshAppointments, user],
  )

  const handleMarkAppointmentCompleted = useCallback(
    async (appointment: PatientAppointment) => {
      if (!isDoctor || !user) {
        setAppointmentFeedback({
          type: 'error',
          message: 'Action reservee au medecin.',
        })
        return
      }

      setPendingAppointmentId(appointment.id)
      setAppointmentFeedback(null)
      try {
        await markAppointmentCompleted({
          appointment,
          doctorId: user.id,
        })
        setAppointmentFeedback({
          type: 'success',
          message: 'Rendez-vous marque comme termine.',
        })
        await refreshAppointments()
      } catch (markError) {
        setAppointmentFeedback({
          type: 'error',
          message: getActionErrorMessage(
            markError,
            'Impossible de marquer ce rendez-vous comme termine.',
          ),
        })
      } finally {
        setPendingAppointmentId(null)
      }
    },
    [isDoctor, refreshAppointments, user],
  )

  const handleConfirmDelete = useCallback(async () => {
    if (!isDoctor) {
      setAppointmentFeedback({
        type: 'error',
        message: 'Action reservee au medecin.',
      })
      return
    }

    const appointment = deleteDialog.appointment
    if (!appointment) {
      return
    }

    setPendingAppointmentId(appointment.id)
    setAppointmentFeedback(null)
    try {
      await deleteAppointment(appointment.id)
      setDeleteDialog(CLOSED_DELETE_DIALOG)
      setAppointmentFeedback({
        type: 'success',
        message: 'Rendez-vous supprime avec succes.',
      })
      await refreshAppointments()
    } catch (deleteError) {
      setAppointmentFeedback({
        type: 'error',
        message: getActionErrorMessage(
          deleteError,
          'Impossible de supprimer le rendez-vous.',
        ),
      })
    } finally {
      setPendingAppointmentId(null)
    }
  }, [deleteDialog.appointment, isDoctor, refreshAppointments])

  const handleSubmitMedication = useCallback(
    async (values: MedicationFormValues) => {
      if (!isDoctor || !user || !patientId) {
        setMedicationFeedback({
          type: 'error',
          message: 'Action reservee au medecin.',
        })
        return
      }

      setIsSubmittingMedication(true)
      setMedicationFeedback(null)

      try {
        if (medicationDialog.mode === 'edit' && medicationDialog.medication) {
          await updateMedication({
            medicationId: medicationDialog.medication.id,
            patientId,
            doctorId: user.id,
            prescriptionId: medicationDialog.medication.prescription_id,
            name: values.name,
            dosage: values.dosage,
            form: values.form,
            quantity: values.quantity,
            frequency: values.frequency,
            period: values.period,
            startDate: values.startDate,
            endDate: values.endDate || null,
            instructions: values.instructions,
          })
          setMedicationFeedback({
            type: 'success',
            message: 'Traitement modifie avec succes.',
          })
        } else {
          await createMedication({
            patientId,
            doctorId: user.id,
            prescriptionId: null,
            name: values.name,
            dosage: values.dosage,
            form: values.form,
            quantity: values.quantity,
            frequency: values.frequency,
            period: values.period,
            startDate: values.startDate,
            endDate: values.endDate || null,
            instructions: values.instructions,
          })
          setMedicationFeedback({
            type: 'success',
            message: 'Traitement ajoute avec succes.',
          })
        }

        setMedicationDialog(CLOSED_MEDICATION_DIALOG)
        await refreshMedications()
      } catch (medicationError) {
        setMedicationFeedback({
          type: 'error',
          message: getActionErrorMessage(
            medicationError,
            medicationDialog.mode === 'edit'
              ? 'Impossible de modifier le traitement.'
              : 'Impossible de creer le traitement.',
          ),
        })
      } finally {
        setIsSubmittingMedication(false)
      }
    },
    [isDoctor, medicationDialog, patientId, refreshMedications, user],
  )

  const handleSubmitPrescription = useCallback(
    async (values: PrescriptionFormValues) => {
      if (!isDoctor || !user || !patientId) {
        setPrescriptionFeedback({
          type: 'error',
          message: 'Action reservee au medecin.',
        })
        return
      }

      const medicationItems: PrescriptionItem[] = values.medications.map(
        mapMedicationFormDataToPrescriptionItem,
      )

      setIsSubmittingPrescription(true)
      setPrescriptionFeedback(null)
      try {
        const created = await createPrescriptionWithItems({
          patientId,
          doctorId: user.id,
          prescriptionDate: values.prescriptionDate,
          notes: values.notes,
          medications: medicationItems,
          status: 'active',
        })
        setIsPrescriptionFormOpen(false)
        setPrescriptionDetailsDialog({
          isOpen: true,
          detail: {
            prescription: created.prescription,
            medications: created.medications,
          },
        })
        setPrescriptionFeedback({
          type: 'success',
          message: 'Ordonnance creee avec succes. Voir ou imprimer disponible.',
        })
        await Promise.all([refreshPrescriptions(), refreshMedications()])
      } catch (submitError) {
        setPrescriptionFeedback({
          type: 'error',
          message: getActionErrorMessage(
            submitError,
            'Impossible de creer l ordonnance.',
          ),
        })
      } finally {
        setIsSubmittingPrescription(false)
      }
    },
    [
      isDoctor,
      patientId,
      refreshMedications,
      refreshPrescriptions,
      user,
    ],
  )

  const handleSubmitAllergy = useCallback(
    async (values: AllergyFormValues) => {
      if (!isDoctor || !patientId) {
        setAllergyFeedback({
          type: 'error',
          message: 'Action reservee au medecin.',
        })
        return
      }

      setIsSubmittingAllergy(true)
      setAllergyFeedback(null)
      try {
        await createPatientAllergy(patientId, {
          allergen: values.allergen,
          reaction: values.reaction,
          severity: values.severity,
          notes: values.notes.trim() || null,
        })
        setIsAllergyFormOpen(false)
        setAllergyFeedback({
          type: 'success',
          message: 'Allergie ajoutee avec succes.',
        })
        await refreshAllergies()
      } catch (submitError) {
        setAllergyFeedback({
          type: 'error',
          message: getActionErrorMessage(
            submitError,
            'Impossible d ajouter cette allergie.',
          ),
        })
      } finally {
        setIsSubmittingAllergy(false)
      }
    },
    [isDoctor, patientId, refreshAllergies],
  )

  const openPrescriptionDetails = useCallback(
    async (prescription: Prescription) => {
      setPendingPrescriptionId(prescription.id)
      setPrescriptionFeedback(null)

      try {
        const refreshedPrescription = await getPrescriptionById(prescription.id)
        const medications = medicationsByPrescriptionId.get(prescription.id) ?? []
        setPrescriptionDetailsDialog({
          isOpen: true,
          detail: {
            prescription: refreshedPrescription,
            medications,
          },
        })
      } catch (detailError) {
        setPrescriptionFeedback({
          type: 'error',
          message: getActionErrorMessage(
            detailError,
            'Impossible de charger le detail ordonnance.',
          ),
        })
      } finally {
        setPendingPrescriptionId(null)
      }
    },
    [medicationsByPrescriptionId],
  )

  const handlePrintPrescription = useCallback(() => {
    const detail = prescriptionDetailsDialog.detail
    if (!detail || !patient) {
      return
    }

    const prescriberLabel = resolvePrescriberLabel(detail.prescription.doctor_id)

    setIsPrintingPrescription(true)
    try {
      const printed = printPrescription({
        detail,
        doctorDisplayName: prescriberLabel,
        patientFullName: `${patient.first_name} ${patient.last_name}`.trim(),
        patientCode: patient.patient_code || `P-${patient.id}`,
        patientCin: patient.cin,
        patientAgeLabel: `${getAgeFromBirthDate(patient.birth_date)} ans`,
      })

      if (!printed) {
        setPrescriptionFeedback({
          type: 'error',
          message: 'Impossible d ouvrir la fenetre d impression.',
        })
      }
    } finally {
      setIsPrintingPrescription(false)
    }
  }, [patient, prescriptionDetailsDialog.detail, resolvePrescriberLabel])

  const handleMarkMedicationCompleted = useCallback(
    async (medication: PatientMedication) => {
      if (!isDoctor) {
        setMedicationFeedback({
          type: 'error',
          message: 'Action reservee au medecin.',
        })
        return
      }

      if (!isMedicationActive(medication)) {
        return
      }

      setPendingMedicationId(medication.id)
      setMedicationFeedback(null)
      try {
        await markMedicationCompleted(medication.id)
        setMedicationFeedback({
          type: 'success',
          message: 'Traitement marque comme termine.',
        })
        await refreshMedications()
      } catch (markError) {
        setMedicationFeedback({
          type: 'error',
          message: getActionErrorMessage(
            markError,
            'Impossible de marquer le traitement termine.',
          ),
        })
      } finally {
        setPendingMedicationId(null)
      }
    },
    [isDoctor, refreshMedications],
  )

  const handleMarkMedicationTaken = useCallback(
    async (medication: PatientMedication) => {
      if (!isFamily || !isMedicationActive(medication)) {
        return
      }

      setPendingMedicationId(medication.id)
      setMedicationFeedback(null)
      try {
        await createMedicationIntake({
          medicationId: medication.id,
          status: 'taken',
        })
        setMedicationFeedback({
          type: 'success',
          message: 'Prise du medicament enregistree.',
        })
        await refreshMedications()
      } catch (intakeError) {
        setMedicationFeedback({
          type: 'error',
          message: getActionErrorMessage(
            intakeError,
            'Impossible d enregistrer la prise du medicament.',
          ),
        })
      } finally {
        setPendingMedicationId(null)
      }
    },
    [isFamily, refreshMedications],
  )

  const handleConfirmMedicationAction = useCallback(async () => {
    if (!isDoctor) {
      setMedicationFeedback({
        type: 'error',
        message: 'Action reservee au medecin.',
      })
      return
    }

    const medication = medicationConfirmationDialog.medication
    if (!medication) {
      return
    }

    setPendingMedicationId(medication.id)
    setMedicationFeedback(null)
    try {
      if (medicationConfirmationDialog.action === 'stop') {
        await stopMedication(medication.id)
        setMedicationFeedback({
          type: 'success',
          message: 'Traitement arrete.',
        })
      } else {
        await deleteMedication(medication.id)
        setMedicationFeedback({
          type: 'success',
          message: 'Traitement supprime.',
        })
      }

      setMedicationConfirmationDialog(CLOSED_MEDICATION_CONFIRM_DIALOG)
      await refreshMedications()
    } catch (actionError) {
      setMedicationFeedback({
        type: 'error',
        message: getActionErrorMessage(
          actionError,
          medicationConfirmationDialog.action === 'stop'
            ? 'Impossible d arreter ce traitement.'
            : 'Impossible de supprimer ce traitement.',
        ),
      })
    } finally {
      setPendingMedicationId(null)
    }
  }, [isDoctor, medicationConfirmationDialog, refreshMedications])

  const handleMarkAlertRead = useCallback(async (alert: PatientAlert) => {
    if (!isDoctor || alert.is_read) {
      return
    }

    setPendingAlertId(alert.id)
    setAlertFeedback(null)
    setAlertsState((currentState) => {
      const index = currentState.items.findIndex((item) => item.id === alert.id)
      if (index < 0) {
        return currentState
      }

      const nextItems = [...currentState.items]
      nextItems[index] = {
        ...nextItems[index],
        is_read: true,
      }

      return {
        ...currentState,
        items: nextItems,
      }
    })

    try {
      await markAlertRead(alert.id)
      setAlertFeedback({
        type: 'success',
        message: 'Alerte marquee comme lue.',
      })
      await refreshAlerts()
    } catch (markError) {
      setAlertsState((currentState) => {
        const index = currentState.items.findIndex((item) => item.id === alert.id)
        if (index < 0) {
          return currentState
        }

        const nextItems = [...currentState.items]
        nextItems[index] = alert

        return {
          ...currentState,
          items: nextItems,
        }
      })
      setAlertFeedback({
        type: 'error',
        message: getActionErrorMessage(
          markError,
          'Impossible de marquer l alerte comme lue.',
        ),
      })
    } finally {
      setPendingAlertId(null)
    }
  }, [isDoctor, refreshAlerts])

  const patientFullName = useMemo(() => {
    if (!patient) return 'Patient'
    return `${patient.first_name} ${patient.last_name}`.trim()
  }, [patient])

  return (
    <DoctorShellLayout title="Fiche patient">
      <AppHeader
        actions={
          <Link className="btn btn-outline" to="/patients">
            Retour patients
          </Link>
        }
        subtitle="Informations principales du dossier patient."
        title="Fiche patient"
      />

      {isLoading && (
        <SectionCard title="Chargement">
          <p className="state-text">Chargement du patient...</p>
        </SectionCard>
      )}

      {!isLoading && error && (
        <SectionCard title="Chargement impossible">
          <EmptyState iconLabel="ERR" message={error} title="Erreur" />
        </SectionCard>
      )}

      {!isLoading && !error && patient && (
        <>
          <article className="patient-header-card">
            <span className="patient-header-icon" aria-hidden>
              PAT
            </span>

            <div className="patient-header-main">
              <h2>
                {patient.first_name} {patient.last_name}
              </h2>

              <div className="patient-fact-chip-row">
                <StatusBadge
                  label={getPatientStatusLabel(patientComputedStatus)}
                  tone={getPatientStatusTone(patientComputedStatus)}
                />
                <span className="fact-chip">
                  ID {patient.patient_code || `P-${patient.id}`}
                </span>
                <span className="fact-chip">
                  {getAgeFromBirthDate(patient.birth_date)} ans
                </span>
                <span className="fact-chip">CIN {patient.cin}</span>
                <span className="fact-chip">
                  Ne(e) le {formatDateOnly(patient.birth_date)}
                </span>
                <span className="fact-chip">
                  Cree le {formatDateTime(patient.created_at)}
                </span>
              </div>
            </div>
          </article>

          <div className="patient-sections-grid">
            {!isDoctor && (
              <SectionCard title="Rendez-vous recents">
              {appointmentFeedback && (
                <div
                  className={
                    appointmentFeedback.type === 'success'
                      ? 'feedback-banner is-success'
                      : 'feedback-banner is-error'
                  }
                  role="status"
                >
                  {appointmentFeedback.message}
                </div>
              )}

              <SectionRenderer
                emptyMessage="Ce patient n a pas encore de rendez-vous planifie."
                emptyTitle="Aucun rendez-vous"
                getKey={(item) => `appointment-${item.id}`}
                renderItem={(item) => {
                  const effectiveStatus = getEffectiveAppointmentStatus(item)
                  const isBusy = pendingAppointmentId === item.id

                  return (
                    <div className="appointment-item">
                      <span aria-hidden className="appointment-icon">
                        RV
                      </span>
                      <div className="appointment-main">
                        <div className="record-head">
                          <strong>{formatDateTime(item.appointment_date)}</strong>
                          <StatusBadge
                            label={formatAppointmentStatus(effectiveStatus)}
                            tone={getAppointmentTone(effectiveStatus)}
                          />
                        </div>
                        {item.notes && <p className="record-text">{item.notes}</p>}
                        {isDoctor && (
                          <div className="appointment-actions">
                            <button
                              className="appointment-action-button"
                              disabled={isBusy}
                              onClick={() => openEditAppointmentDialog(item)}
                              type="button"
                            >
                              Modifier
                            </button>
                            {canMarkAppointmentCompleted(item) && (
                              <button
                                className="appointment-action-button"
                                disabled={isBusy}
                                onClick={() => {
                                  void handleMarkAppointmentCompleted(item)
                                }}
                                type="button"
                              >
                                Marquer termine
                              </button>
                            )}
                            <button
                              className="appointment-action-button danger"
                              disabled={isBusy}
                              onClick={() => openDeleteDialog(item)}
                              type="button"
                            >
                              Supprimer
                            </button>
                          </div>
                        )}
                      </div>
                    </div>
                  )
                }}
                state={appointmentsState}
              />
              </SectionCard>
            )}

            {!isDoctor && (
              <SectionCard title="Derniere localisation">
              {locationState.isLoading && (
                <p className="state-text">Chargement...</p>
              )}

              {!locationState.isLoading && locationState.error && (
                <EmptyState
                  iconLabel="ERR"
                  message={locationState.error}
                  title="Chargement impossible"
                />
              )}

              {!locationState.isLoading &&
                !locationState.error &&
                !locationState.location && (
                  <EmptyState
                    iconLabel="GPS"
                    message="Aucune position n a encore ete enregistree pour ce patient."
                    title="Aucune localisation disponible"
                  />
                )}

              {!locationState.isLoading &&
                !locationState.error &&
                locationState.location && (
                  <div className="record-list">
                    <article className="record-card">
                      <div className="record-head">
                        <strong>Position transmise</strong>
                        <StatusBadge label="Disponible" tone="primary" />
                      </div>
                      <p className="record-text">
                        {formatCoordinates(
                          locationState.location.latitude,
                          locationState.location.longitude,
                        )}
                      </p>
                      <p className="record-subtext">
                        Transmise le {formatDateTime(locationState.location.recorded_at)}
                      </p>
                    </article>
                  </div>
                )}
              </SectionCard>
            )}

            {!isDoctor && (
              <SectionCard title="Alertes">
              {alertFeedback && (
                <div
                  className={
                    alertFeedback.type === 'success'
                      ? 'feedback-banner is-success'
                      : 'feedback-banner is-error'
                  }
                  role="status"
                >
                  {alertFeedback.message}
                </div>
              )}

              <SectionRenderer
                emptyMessage="Aucune alerte enregistree pour ce patient."
                emptyTitle="Aucune alerte"
                getKey={(item) => `alert-${item.id}`}
                renderItem={(item) => (
                  <div className={item.is_read ? 'alert-item' : 'alert-item is-unread'}>
                    <div className="record-head">
                      <StatusBadge
                        label={getAlertTypeLabel(item.type)}
                        tone={getAlertTypeTone(item.type)}
                      />
                      <StatusBadge
                        label={item.is_read ? 'Lue' : 'Non lue'}
                        tone={getAlertReadTone(item.is_read)}
                      />
                    </div>
                    <p className="record-text">{item.message}</p>
                    <p className="record-subtext">
                      Date: {formatDateTime(item.created_at)}
                    </p>
                    {isDoctor && !item.is_read && (
                      <div className="appointment-actions">
                        <button
                          className="appointment-action-button"
                          disabled={pendingAlertId === item.id}
                          onClick={() => {
                            void handleMarkAlertRead(item)
                          }}
                          type="button"
                        >
                          Marquer lue
                        </button>
                      </div>
                    )}
                  </div>
                )}
                state={alertsState}
              />
              </SectionCard>
            )}

            <SectionCard title="Medicaments actifs">
              {medicationFeedback && (
                <div
                  className={
                    medicationFeedback.type === 'success'
                      ? 'feedback-banner is-success'
                      : 'feedback-banner is-error'
                  }
                  role="status"
                >
                  {medicationFeedback.message}
                </div>
              )}

              <SectionRenderer
                emptyMessage="Aucun medicament actif pour ce patient."
                emptyTitle="Aucun traitement actif"
                getKey={(item) => `medication-${item.id}`}
                renderItem={(item) => {
                  const isBusy = pendingMedicationId === item.id
                  const isActive = isMedicationActive(item)

                  return (
                    <>
                      <div className="record-head">
                        <strong>{item.name}</strong>
                        <StatusBadge
                          label={formatMedicationStatus(item.status)}
                          tone={getMedicationTone(item.status)}
                        />
                      </div>
                      <p className="record-text">
                        {joinNonEmpty([item.dosage, item.frequency]) ||
                          'Details non disponibles'}
                      </p>
                      <p className="record-subtext">
                        {joinNonEmpty([item.form, item.quantity, item.period]) ||
                          'Aucun detail supplementaire'}
                      </p>
                      <p className="record-subtext">
                        Periode:{' '}
                        {joinNonEmpty(
                          [
                            formatDateOnlyNullable(item.start_date),
                            formatDateOnlyNullable(item.end_date),
                          ],
                          ' -> ',
                        ) || 'Non precisee'}
                      </p>
                      {item.instructions && (
                        <p className="record-subtext">
                          Instructions: {item.instructions}
                        </p>
                      )}
                      {isActive && (
                        <div className="appointment-actions">
                          {isDoctor && (
                            <>
                              <button
                                className="appointment-action-button"
                                disabled={isBusy}
                                onClick={() => openEditMedicationDialog(item)}
                                type="button"
                              >
                                Modifier
                              </button>
                              <button
                                className="appointment-action-button"
                                disabled={isBusy}
                                onClick={() => {
                                  void handleMarkMedicationCompleted(item)
                                }}
                                type="button"
                              >
                                Marquer termine
                              </button>
                              <button
                                className="appointment-action-button"
                                disabled={isBusy}
                                onClick={() => openMedicationStopDialog(item)}
                                type="button"
                              >
                                Arreter
                              </button>
                              <button
                                className="appointment-action-button danger"
                                disabled={isBusy}
                                onClick={() => openMedicationDeleteDialog(item)}
                                type="button"
                              >
                                Supprimer
                              </button>
                            </>
                          )}
                          {isFamily && (
                            <button
                              className="appointment-action-button"
                              disabled={isBusy}
                              onClick={() => {
                                void handleMarkMedicationTaken(item)
                              }}
                              type="button"
                            >
                              Marquer pris
                            </button>
                          )}
                        </div>
                      )}
                    </>
                  )
                }}
                state={medicationsState}
              />
            </SectionCard>

            <SectionCard
              action={isDoctor
                ? (
                    <button
                      className="btn btn-outline"
                      onClick={openPrescriptionForm}
                      type="button"
                    >
                      Nouvelle ordonnance
                    </button>
                  )
                : undefined}
              title="Historique des ordonnances"
            >
              {prescriptionFeedback && (
                <div
                  className={
                    prescriptionFeedback.type === 'success'
                      ? 'feedback-banner is-success'
                      : 'feedback-banner is-error'
                  }
                  role="status"
                >
                  {prescriptionFeedback.message}
                </div>
              )}

              <SectionRenderer
                emptyMessage="Aucune ordonnance disponible pour ce patient."
                emptyTitle="Aucune ordonnance"
                getKey={(item) => `prescription-${item.id}`}
                renderItem={(item) => {
                  const isBusy = pendingPrescriptionId === item.id
                  const medications =
                    medicationsByPrescriptionId.get(item.id) ?? []

                  return (
                    <>
                      <div className="record-head">
                        <strong>Ordonnance du {formatDateOnly(item.prescription_date)}</strong>
                        <StatusBadge
                          label={formatPrescriptionStatus(item.status)}
                          tone={getPrescriptionTone(item.status)}
                        />
                      </div>
                      <p className="record-subtext">
                        Prescripteur: {resolvePrescriberLabel(item.doctor_id)}
                      </p>
                      <p className="record-subtext">
                        Medicaments: {medications.length}
                      </p>
                      {item.notes && (
                        <p className="record-subtext">Notes: {item.notes}</p>
                      )}
                      <div className="appointment-actions">
                        <button
                          className="appointment-action-button"
                          disabled={isBusy}
                          onClick={() => {
                            void openPrescriptionDetails(item)
                          }}
                          type="button"
                        >
                          Voir detail
                        </button>
                      </div>
                    </>
                  )
                }}
                state={prescriptionsState}
              />
            </SectionCard>

            {!isDoctor && (
              <SectionCard title="Allergies">
              {allergyFeedback && (
                <div
                  className={
                    allergyFeedback.type === 'success'
                      ? 'feedback-banner is-success'
                      : 'feedback-banner is-error'
                  }
                  role="status"
                >
                  {allergyFeedback.message}
                </div>
              )}

              <SectionRenderer
                emptyMessage="Aucune allergie enregistree pour ce patient."
                emptyTitle="Aucune allergie"
                getKey={(item) => `allergy-${item.id}`}
                renderItem={(item) => (
                  <>
                    <div className="record-head">
                      <strong>{item.allergen}</strong>
                      <StatusBadge
                        label={getAllergySeverityLabel(item.severity)}
                        tone={getAllergySeverityTone(item.severity)}
                      />
                    </div>
                    <p className="record-text">
                      {item.reaction?.trim() || 'Reaction non precisee'}
                    </p>
                    {item.notes && (
                      <p className="record-subtext">Notes: {item.notes}</p>
                    )}
                    {item.created_at && (
                      <p className="record-subtext">
                        Date: {formatDateTime(item.created_at)}
                      </p>
                    )}
                  </>
                )}
                state={allergiesState}
              />
              </SectionCard>
            )}

            <SectionCard title="Medicaments termines / annules">
              <SectionRenderer
                emptyMessage="Aucun medicament termine ou arrete."
                emptyTitle="Aucun historique traitement"
                getKey={(item) => `medication-archived-${item.id}`}
                renderItem={(item) => (
                  <>
                    <div className="record-head">
                      <strong>{item.name}</strong>
                      <StatusBadge
                        label={formatMedicationStatus(item.status)}
                        tone={getMedicationTone(item.status)}
                      />
                    </div>
                    <p className="record-text">
                      {joinNonEmpty([item.dosage, item.frequency]) ||
                        'Details non disponibles'}
                    </p>
                    <p className="record-subtext">
                      Periode:{' '}
                      {joinNonEmpty(
                        [
                          formatDateOnlyNullable(item.start_date),
                          formatDateOnlyNullable(item.end_date),
                        ],
                        ' -> ',
                      ) || 'Non precisee'}
                    </p>
                  </>
                )}
                state={archivedMedicationsState}
              />
            </SectionCard>

            {isDoctor && (
              <SectionCard
                action={
                  <button
                    className="btn btn-outline"
                    onClick={openAllergyForm}
                    type="button"
                  >
                    Ajouter allergie
                  </button>
                }
                title="Allergies"
              >
                {allergyFeedback && (
                  <div
                    className={
                      allergyFeedback.type === 'success'
                        ? 'feedback-banner is-success'
                        : 'feedback-banner is-error'
                    }
                    role="status"
                  >
                    {allergyFeedback.message}
                  </div>
                )}

                <SectionRenderer
                  emptyMessage="Aucune allergie enregistree pour ce patient."
                  emptyTitle="Aucune allergie"
                  getKey={(item) => `allergy-${item.id}`}
                  renderItem={(item) => (
                    <>
                      <div className="record-head">
                        <strong>{item.allergen}</strong>
                        <StatusBadge
                          label={getAllergySeverityLabel(item.severity)}
                          tone={getAllergySeverityTone(item.severity)}
                        />
                      </div>
                      <p className="record-text">
                        {item.reaction?.trim() || 'Reaction non precisee'}
                      </p>
                      {item.notes && (
                        <p className="record-subtext">Notes: {item.notes}</p>
                      )}
                      {item.created_at && (
                        <p className="record-subtext">
                          Date: {formatDateTime(item.created_at)}
                        </p>
                      )}
                    </>
                  )}
                  state={allergiesState}
                />
              </SectionCard>
            )}

            {isDoctor && (
              <SectionCard
                action={
                  <button
                    className="btn btn-outline"
                    onClick={openCreateAppointmentDialog}
                    type="button"
                  >
                    Ajouter
                  </button>
                }
                title="Rendez-vous"
              >
                {appointmentFeedback && (
                  <div
                    className={
                      appointmentFeedback.type === 'success'
                        ? 'feedback-banner is-success'
                        : 'feedback-banner is-error'
                    }
                    role="status"
                  >
                    {appointmentFeedback.message}
                  </div>
                )}

                <SectionRenderer
                  emptyMessage="Ce patient n a pas encore de rendez-vous planifie."
                  emptyTitle="Aucun rendez-vous"
                  getKey={(item) => `appointment-${item.id}`}
                  renderItem={(item) => {
                    const effectiveStatus = getEffectiveAppointmentStatus(item)
                    const isBusy = pendingAppointmentId === item.id

                    return (
                      <div className="appointment-item">
                        <span aria-hidden className="appointment-icon">
                          RV
                        </span>
                        <div className="appointment-main">
                          <div className="record-head">
                            <strong>{formatDateTime(item.appointment_date)}</strong>
                            <StatusBadge
                              label={formatAppointmentStatus(effectiveStatus)}
                              tone={getAppointmentTone(effectiveStatus)}
                            />
                          </div>
                          {item.notes && <p className="record-text">{item.notes}</p>}
                          <div className="appointment-actions">
                            <button
                              className="appointment-action-button"
                              disabled={isBusy}
                              onClick={() => openEditAppointmentDialog(item)}
                              type="button"
                            >
                              Modifier
                            </button>
                            {canMarkAppointmentCompleted(item) && (
                              <button
                                className="appointment-action-button"
                                disabled={isBusy}
                                onClick={() => {
                                  void handleMarkAppointmentCompleted(item)
                                }}
                                type="button"
                              >
                                Marquer termine
                              </button>
                            )}
                            <button
                              className="appointment-action-button danger"
                              disabled={isBusy}
                              onClick={() => openDeleteDialog(item)}
                              type="button"
                            >
                              Supprimer
                            </button>
                          </div>
                        </div>
                      </div>
                    )
                  }}
                  state={appointmentsState}
                />
              </SectionCard>
            )}

            {isDoctor && (
              <PatientAiResultsCard
                diagnoses={diagnosesState.items}
                doctors={patientDoctors}
                error={diagnosesState.error}
                isLoading={diagnosesState.isLoading}
              />
            )}

            {!isDoctor && (
              <SectionCard title="Diagnostics">
              <SectionRenderer
                emptyMessage="Aucun diagnostic pour ce patient."
                emptyTitle="Aucun diagnostic"
                getKey={(item) => `diagnosis-${item.id}`}
                renderItem={(item) => (
                  <>
                    <div className="record-head">
                      <strong>Diagnostic #{item.id}</strong>
                      <span className="record-date">
                        {formatDateTime(item.created_at)}
                      </span>
                    </div>
                    <p className="record-text">{item.model_result}</p>
                    {(item.confidence_score !== null ||
                      item.questionnaire_score !== null) && (
                      <p className="record-subtext">
                        {joinNonEmpty([
                          item.confidence_score !== null
                            ? `Confidence: ${item.confidence_score}`
                            : null,
                          item.questionnaire_score !== null
                            ? `Score questionnaire: ${item.questionnaire_score}`
                            : null,
                        ])}
                      </p>
                    )}
                    {item.final_medical_opinion && (
                      <p className="record-subtext">
                        Avis final: {item.final_medical_opinion}
                      </p>
                    )}
                  </>
                )}
                state={diagnosesState}
              />
              </SectionCard>
            )}

            {!isDoctor && (
              <SectionCard title="Notes medicales">
              <SectionRenderer
                emptyMessage="Aucune note medicale pour ce patient."
                emptyTitle="Aucune note medicale"
                getKey={(item) => `note-${item.id}`}
                renderItem={(item) => (
                  <>
                    <div className="record-head">
                      <strong>Note #{item.id}</strong>
                      <span className="record-date">
                        {formatDateTime(item.created_at)}
                      </span>
                    </div>
                    <p className="record-text">{item.note}</p>
                  </>
                )}
                state={notesState}
              />
              </SectionCard>
            )}
          </div>
        </>
      )}

      {isDoctor && (
        <AppointmentFormDialog
          key={`${appointmentDialog.mode}-${appointmentDialog.appointment?.id ?? 'create'}-${appointmentDialog.isOpen ? 'open' : 'closed'}`}
          initialAppointment={appointmentDialog.appointment}
          isOpen={appointmentDialog.isOpen}
          isSubmitting={isSubmittingAppointment}
          mode={appointmentDialog.mode}
          onClose={closeAppointmentDialog}
          onSubmit={handleSubmitAppointment}
          patientName={patientFullName}
        />
      )}

      {isDoctor && (
        <MedicationFormDialog
          key={`${medicationDialog.mode}-${medicationDialog.medication?.id ?? 'create'}-${medicationDialog.isOpen ? 'open' : 'closed'}`}
          initialMedication={medicationDialog.medication}
          isOpen={medicationDialog.isOpen}
          isSubmitting={isSubmittingMedication}
          mode={medicationDialog.mode}
          onClose={closeMedicationDialog}
          onSubmit={handleSubmitMedication}
          patientName={patientFullName}
        />
      )}

      {isDoctor && (
        <PrescriptionFormDialog
          key={isPrescriptionFormOpen ? 'prescription-form-open' : 'prescription-form-closed'}
          isOpen={isPrescriptionFormOpen}
          isSubmitting={isSubmittingPrescription}
          onClose={closePrescriptionForm}
          onSubmit={handleSubmitPrescription}
          patientName={patientFullName}
        />
      )}

      {isDoctor && (
        <AllergyFormDialog
          key={isAllergyFormOpen ? 'allergy-form-open' : 'allergy-form-closed'}
          isOpen={isAllergyFormOpen}
          isSubmitting={isSubmittingAllergy}
          onClose={closeAllergyForm}
          onSubmit={handleSubmitAllergy}
          patientName={patientFullName}
        />
      )}

      <PrescriptionDetailsDialog
        detail={prescriptionDetailsDialog.detail}
        isOpen={prescriptionDetailsDialog.isOpen}
        isPrinting={isPrintingPrescription}
        onClose={closePrescriptionDetails}
        onPrint={handlePrintPrescription}
        patientAgeLabel={
          patient ? `${getAgeFromBirthDate(patient.birth_date)} ans` : 'Non disponible'
        }
        patientCin={patient?.cin ?? 'Non disponible'}
        patientCode={patient?.patient_code || (patient ? `P-${patient.id}` : 'Non disponible')}
        patientName={patientFullName}
        prescriberLabel={
          prescriptionDetailsDialog.detail
            ? resolvePrescriberLabel(
                prescriptionDetailsDialog.detail.prescription.doctor_id,
              )
            : 'Non disponible'
        }
      />

      {isDoctor && (
        <ConfirmationDialog
          confirmLabel="Supprimer"
          isOpen={deleteDialog.isOpen}
          isSubmitting={pendingAppointmentId !== null}
          message={
            deleteDialog.appointment
              ? `Supprimer le rendez-vous du ${formatDateTime(
                  deleteDialog.appointment.appointment_date,
                )} ?`
              : ''
          }
          onCancel={closeDeleteDialog}
          onConfirm={handleConfirmDelete}
          title="Supprimer rendez-vous"
        />
      )}

      {isDoctor && (
        <ConfirmationDialog
          confirmLabel={
            medicationConfirmationDialog.action === 'stop' ? 'Arreter' : 'Supprimer'
          }
          isOpen={medicationConfirmationDialog.isOpen}
          isSubmitting={pendingMedicationId !== null}
          message={
            medicationConfirmationDialog.medication
              ? medicationConfirmationDialog.action === 'stop'
                ? `Arreter le traitement ${medicationConfirmationDialog.medication.name} ?`
                : `Supprimer le traitement ${medicationConfirmationDialog.medication.name} ?`
              : ''
          }
          onCancel={closeMedicationConfirmationDialog}
          onConfirm={handleConfirmMedicationAction}
          submittingLabel={
            medicationConfirmationDialog.action === 'stop'
              ? 'Arret...'
              : 'Suppression...'
          }
          title={
            medicationConfirmationDialog.action === 'stop'
              ? 'Arreter traitement'
              : 'Supprimer traitement'
          }
        />
      )}
    </DoctorShellLayout>
  )
}
