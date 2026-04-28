import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'

import { useAuth } from '../../../core/auth/useAuth'
import { EmptyState } from '../../../shared/ui/EmptyState'
import {
  createAppointment,
  getDoctorAppointments,
  getDoctorPatients,
} from '../../patients/api/patientsApi'
import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { SectionCard } from '../../../shared/ui/SectionCard'
import { StatusBadge } from '../../../shared/ui/StatusBadge'
import {
  DashboardAppointmentFormDialog,
  type DashboardAppointmentFormValues,
} from '../components/DashboardAppointmentFormDialog'
import {
  type DashboardAppointment,
  MonthlyAppointmentsCalendar,
} from '../components/MonthlyAppointmentsCalendar'
import type { AppointmentStatus, Patient } from '../../patients/types'

interface DashboardMetrics {
  patientsCount: number
  appointments: DashboardAppointment[]
}

interface DashboardAppointmentDialogState {
  isOpen: boolean
  initialDate: string
}

interface ActionFeedback {
  type: 'success' | 'error'
  message: string
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return 'Impossible de charger le resume du dashboard.'
}

function getDateOnlyKey(value: string): string | null {
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return null
  }

  const year = parsed.getFullYear().toString().padStart(4, '0')
  const month = `${parsed.getMonth() + 1}`.padStart(2, '0')
  const day = `${parsed.getDate()}`.padStart(2, '0')
  return `${year}-${month}-${day}`
}

function isToday(dateValue: string): boolean {
  const currentDateKey = getDateOnlyKey(new Date().toISOString())
  const testedDateKey = getDateOnlyKey(dateValue)

  if (!currentDateKey || !testedDateKey) {
    return false
  }
  return currentDateKey === testedDateKey
}

function toTimestamp(value: string): number {
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return Number.POSITIVE_INFINITY
  }
  return parsed.getTime()
}

function formatAppointmentTime(value: string): string {
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return value
  }
  return parsed.toLocaleTimeString('fr-FR', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatAppointmentDate(value: string): string {
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return value
  }
  return parsed.toLocaleDateString('fr-FR')
}

function formatDateKey(value: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
  if (match) {
    return `${match[3]}/${match[2]}/${match[1]}`
  }
  return value
}

function toDateInput(value: Date): string {
  const year = value.getFullYear().toString().padStart(4, '0')
  const month = `${value.getMonth() + 1}`.padStart(2, '0')
  const day = `${value.getDate()}`.padStart(2, '0')
  return `${year}-${month}-${day}`
}

function toApiDateTime(date: string, time: string): string {
  return `${date}T${time}:00`
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

export function DashboardPage() {
  const { user } = useAuth()
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null)
  const [doctorPatients, setDoctorPatients] = useState<Patient[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [isAppointmentSubmitting, setIsAppointmentSubmitting] = useState(false)
  const [appointmentFeedback, setAppointmentFeedback] =
    useState<ActionFeedback | null>(null)
  const [appointmentDialog, setAppointmentDialog] =
    useState<DashboardAppointmentDialogState>({
      isOpen: false,
      initialDate: toDateInput(new Date()),
    })
  const [selectedCalendarDate, setSelectedCalendarDate] = useState<string>(() => {
    return toDateInput(new Date())
  })

  const greeting = useMemo(() => {
    const firstName = user?.first_name?.trim() ?? ''
    const lastName = user?.last_name?.trim() ?? ''
    if (firstName || lastName) {
      return `Bonjour Dr. ${firstName} ${lastName}`.trim()
    }
    return 'Bonjour Docteur'
  }, [user?.first_name, user?.last_name])

  const todayAppointments = useMemo(() => {
    if (!metrics) {
      return []
    }
    return metrics.appointments
      .filter((item) => isToday(item.appointmentDate))
      .sort((left, right) => {
        return toTimestamp(left.appointmentDate) - toTimestamp(right.appointmentDate)
      })
  }, [metrics])

  const selectedDateAppointments = useMemo(() => {
    if (!metrics) {
      return []
    }
    return metrics.appointments
      .filter((item) => {
        const appointmentDateKey = getDateOnlyKey(item.appointmentDate)
        return appointmentDateKey === selectedCalendarDate
      })
      .sort((left, right) => {
        return toTimestamp(left.appointmentDate) - toTimestamp(right.appointmentDate)
      })
  }, [metrics, selectedCalendarDate])

  const appointmentPatientOptions = useMemo(() => {
    return doctorPatients.map((patient) => {
      return {
        id: patient.id,
        label: `${patient.first_name} ${patient.last_name} (${patient.cin})`.trim(),
      }
    })
  }, [doctorPatients])

  const closeAppointmentDialog = useCallback(() => {
    if (isAppointmentSubmitting) {
      return
    }
    setAppointmentDialog((current) => ({
      ...current,
      isOpen: false,
    }))
  }, [isAppointmentSubmitting])

  const openAppointmentDialog = useCallback((initialDate?: string) => {
    if (doctorPatients.length === 0) {
      setAppointmentFeedback({
        type: 'error',
        message: 'Ajoutez d abord un patient avant de creer un rendez-vous.',
      })
      return
    }

    setAppointmentFeedback(null)
    setAppointmentDialog({
      isOpen: true,
      initialDate: initialDate ?? toDateInput(new Date()),
    })
  }, [doctorPatients.length])

  const loadDashboard = useCallback(async () => {
    if (!user) {
      setMetrics(null)
      setError('Utilisateur non connecte.')
      setIsLoading(false)
      return
    }

    setIsLoading(true)
    setError(null)
    try {
      const [patients, appointments] = await Promise.all([
        getDoctorPatients(user.id),
        getDoctorAppointments(user.id),
      ])
      setDoctorPatients(patients)

      const patientNameById = new Map<number, string>()
      for (const patient of patients) {
        patientNameById.set(
          patient.id,
          `${patient.first_name} ${patient.last_name}`.trim(),
        )
      }

      const normalizedAppointments: DashboardAppointment[] = appointments
        .map((item) => {
          const patientName = patientNameById.get(item.patient_id)
          return {
            id: item.id,
            patientId: item.patient_id,
            patientName: patientName && patientName.length > 0
              ? patientName
              : `Patient #${item.patient_id}`,
            appointmentDate: item.appointment_date,
            notes: item.notes,
            status: item.status,
          }
        })
        .sort((left, right) => {
          return toTimestamp(left.appointmentDate) - toTimestamp(right.appointmentDate)
        })

      setMetrics({
        patientsCount: patients.length,
        appointments: normalizedAppointments,
      })
    } catch (error) {
      setError(getErrorMessage(error))
      setMetrics(null)
      setDoctorPatients([])
    } finally {
      setIsLoading(false)
    }
  }, [user])

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void loadDashboard()
  }, [loadDashboard])

  const handleCreateAppointment = useCallback(
    async (values: DashboardAppointmentFormValues) => {
      if (!user || user.role !== 'doctor') {
        setAppointmentFeedback({
          type: 'error',
          message: 'Action reservee au medecin.',
        })
        return
      }

      setIsAppointmentSubmitting(true)
      setAppointmentFeedback(null)
      try {
        await createAppointment({
          patientId: values.patientId,
          doctorId: user.id,
          appointmentDate: toApiDateTime(values.date, values.time),
          notes: values.notes,
          status: 'scheduled',
        })
        setAppointmentDialog((current) => ({
          ...current,
          isOpen: false,
        }))
        setAppointmentFeedback({
          type: 'success',
          message: 'Rendez-vous ajoute avec succes.',
        })
        await loadDashboard()
      } catch (submitError) {
        setAppointmentFeedback({
          type: 'error',
          message: getErrorMessage(submitError),
        })
      } finally {
        setIsAppointmentSubmitting(false)
      }
    },
    [loadDashboard, user],
  )

  return (
    <DoctorShellLayout title="Dashboard">
      <AppHeader
        actions={
          <div className="dashboard-quick-actions">
            <Link className="btn btn-primary" to="/patients">
              Voir patient
            </Link>
            <Link className="btn btn-primary" to="/patients/new">
              Ajouter patient
            </Link>
            <Link className="btn btn-outline" to="/ai">
              Module IA
            </Link>
          </div>
        }
        subtitle="Vue rapide patients, rendez-vous, alertes et module IA."
        title={greeting}
      />

      {error && (
        <div className="error-banner" role="alert">
          <p>{error}</p>
          <button
            className="btn btn-text"
            onClick={() => {
              void loadDashboard()
            }}
            type="button"
          >
            Reessayer
          </button>
        </div>
      )}

      <section className="kpi-grid">
        <article className="kpi-card">
          <h3>Patients</h3>
          <p className="kpi-value">
            {isLoading ? '--' : (metrics?.patientsCount ?? '--')}
          </p>
          <p className="kpi-subtitle">Total patients lies a votre compte</p>
          <StatusBadge label="Reel" tone="neutral" />
        </article>

        <article className="kpi-card">
          <h3>Rendez-vous (aujourd hui)</h3>
          <p className="kpi-value">
            {isLoading ? '--' : todayAppointments.length}
          </p>
          <p className="kpi-subtitle">Planifies pour la journee</p>
          <StatusBadge label="Aujourd hui" tone="primary" />
        </article>
      </section>

      <SectionCard
        action={
          <span className="section-card-count">
            {isLoading ? '--' : todayAppointments.length}
          </span>
        }
        title="Rendez-vous aujourd hui"
      >
        {isLoading && <p className="state-text">Chargement des rendez-vous...</p>}

        {!isLoading && todayAppointments.length === 0 && (
          <EmptyState
            iconLabel="RV"
            message="Aucun rendez-vous planifie pour cette journee."
            title="Aucun rendez-vous aujourd hui"
          />
        )}

        {!isLoading && todayAppointments.length > 0 && (
          <div className="dashboard-today-list">
            {todayAppointments.map((appointment) => (
              <article className="dashboard-today-item" key={appointment.id}>
                <div className="record-head">
                  <strong>{formatAppointmentTime(appointment.appointmentDate)}</strong>
                  <StatusBadge
                    label={formatAppointmentStatus(appointment.status)}
                    tone={getAppointmentTone(appointment.status)}
                  />
                </div>
                <p className="record-text">{appointment.patientName}</p>
                <p className="record-subtext">
                  Date: {formatAppointmentDate(appointment.appointmentDate)}
                </p>
              </article>
            ))}
          </div>
        )}
      </SectionCard>

      <SectionCard title="Calendrier mensuel">
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

        {isLoading && <p className="state-text">Chargement du calendrier...</p>}
        {!isLoading && (
          <MonthlyAppointmentsCalendar
            appointments={metrics?.appointments ?? []}
            onAddAppointment={() => openAppointmentDialog()}
            onAddAppointmentOnDate={(date) => openAppointmentDialog(date)}
            onSelectDate={(date) => setSelectedCalendarDate(date)}
            selectedDate={selectedCalendarDate}
          />
        )}

        {!isLoading && (
          <div className="dashboard-day-details">
            <div className="dashboard-day-details-header">
              <strong>Date selectionnee: {formatDateKey(selectedCalendarDate)}</strong>
              <span className="section-card-count">{selectedDateAppointments.length}</span>
            </div>

            {selectedDateAppointments.length === 0 && (
              <EmptyState
                iconLabel="RV"
                message="Aucun rendez-vous programme pour cette date."
                title="Journee vide"
              />
            )}

            {selectedDateAppointments.length > 0 && (
              <div className="dashboard-today-list">
                {selectedDateAppointments.map((appointment) => (
                  <article className="dashboard-today-item" key={appointment.id}>
                    <div className="record-head">
                      <strong>{formatAppointmentTime(appointment.appointmentDate)}</strong>
                      <StatusBadge
                        label={formatAppointmentStatus(appointment.status)}
                        tone={getAppointmentTone(appointment.status)}
                      />
                    </div>
                    <p className="record-text">{appointment.patientName}</p>
                    {appointment.notes && (
                      <p className="record-subtext">Notes: {appointment.notes}</p>
                    )}
                  </article>
                ))}
              </div>
            )}
          </div>
        )}
      </SectionCard>

      <DashboardAppointmentFormDialog
        key={`${appointmentDialog.initialDate}-${appointmentDialog.isOpen ? 'open' : 'closed'}`}
        initialDate={appointmentDialog.initialDate}
        isOpen={appointmentDialog.isOpen}
        isSubmitting={isAppointmentSubmitting}
        onClose={closeAppointmentDialog}
        onSubmit={handleCreateAppointment}
        patients={appointmentPatientOptions}
      />
    </DoctorShellLayout>
  )
}
