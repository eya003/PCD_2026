import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'

import { useAuth } from '../../../core/auth/useAuth'
import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { EmptyState } from '../../../shared/ui/EmptyState'
import { SectionCard } from '../../../shared/ui/SectionCard'
import { StatusBadge } from '../../../shared/ui/StatusBadge'
import {
  getDoctorAppointments,
  getDoctorPatients,
  getFamilyPatients,
} from '../api/patientsApi'
import type {
  DoctorAppointmentSummary,
  Patient,
  PatientStatus,
} from '../types'

type PatientFilter = 'all' | PatientStatus

interface PatientListItem extends Patient {
  computedStatus: PatientStatus
  age: number
}

const statusFilters: Array<{ value: PatientFilter; label: string }> = [
  { value: 'all', label: 'Tous' },
  { value: 'suivi', label: 'Suivi' },
  { value: 'nouveau', label: 'Nouveau' },
]

function formatBirthDate(value: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
  if (match) {
    return `${match[3]}/${match[2]}/${match[1]}`
  }
  return value
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

function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return 'Impossible de charger la liste des patients.'
}

function countAppointmentsByPatient(
  appointments: DoctorAppointmentSummary[],
): Map<number, number> {
  const countMap = new Map<number, number>()
  for (const appointment of appointments) {
    const previous = countMap.get(appointment.patient_id) ?? 0
    countMap.set(appointment.patient_id, previous + 1)
  }
  return countMap
}

function resolvePatientStatus(
  patient: Patient,
  appointmentCount: number,
): PatientStatus {
  if (patient.status === 'suivi') return 'suivi'
  if (patient.status === 'nouveau') return 'nouveau'
  if (patient.status === 'a_verifier') return 'a_verifier'
  return appointmentCount >= 2 ? 'suivi' : 'nouveau'
}

function mapToListItem(
  patient: Patient,
  appointmentCounts: Map<number, number>,
): PatientListItem {
  const appointmentCount = appointmentCounts.get(patient.id) ?? 0
  const computedStatus = resolvePatientStatus(patient, appointmentCount)
  const normalizedCode = patient.patient_code.trim()

  return {
    ...patient,
    patient_code:
      normalizedCode.length > 0 ? normalizedCode : `P-${patient.id}`,
    computedStatus,
    age: getAgeFromBirthDate(patient.birth_date),
  }
}

function getStatusLabel(status: PatientStatus): string {
  if (status === 'suivi') return 'Suivi'
  if (status === 'nouveau') return 'Nouveau'
  return 'A verifier'
}

function getStatusTone(status: PatientStatus): 'neutral' | 'primary' | 'warning' {
  if (status === 'suivi') return 'neutral'
  if (status === 'nouveau') return 'primary'
  return 'warning'
}

export function PatientsPage() {
  const { user } = useAuth()
  const [patients, setPatients] = useState<Patient[]>([])
  const [appointmentCounts, setAppointmentCounts] = useState<Map<number, number>>(
    new Map(),
  )
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<PatientFilter>('all')
  const isFamilyView = user?.role === 'family'

  const loadPatients = useCallback(async () => {
    if (!user) {
      setError('Utilisateur non connecte.')
      setPatients([])
      setAppointmentCounts(new Map())
      setIsLoading(false)
      return
    }

    setIsLoading(true)
    setError(null)

    try {
      if (user.role === 'family') {
        const patientsData = await getFamilyPatients(user.id)
        setPatients(patientsData)
        setAppointmentCounts(new Map())
      } else {
        const [patientsData, appointmentsData] = await Promise.all([
          getDoctorPatients(user.id),
          getDoctorAppointments(user.id).catch(() => []),
        ])

        setPatients(patientsData)
        setAppointmentCounts(countAppointmentsByPatient(appointmentsData))
      }
    } catch (loadError) {
      setError(getErrorMessage(loadError))
      setPatients([])
      setAppointmentCounts(new Map())
    } finally {
      setIsLoading(false)
    }
  }, [user])

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void loadPatients()
  }, [loadPatients])

  const visiblePatients = useMemo(() => {
    const query = searchTerm.trim().toLowerCase()
    const items = patients.map((patient) => {
      return mapToListItem(patient, appointmentCounts)
    })

    return items.filter((patient) => {
      if (statusFilter !== 'all' && patient.computedStatus !== statusFilter) {
        return false
      }

      if (!query) {
        return true
      }

      return (
        patient.patient_code.toLowerCase().includes(query) ||
        `${patient.first_name} ${patient.last_name}`.toLowerCase().includes(query) ||
        patient.cin.toLowerCase().includes(query) ||
        `${patient.age}`.includes(query)
      )
    })
  }, [appointmentCounts, patients, searchTerm, statusFilter])

  return (
    <DoctorShellLayout title="Patients">
      <AppHeader
        actions={
          !isFamilyView
            ? (
                <Link className="btn btn-primary" to="/patients/new">
                  Ajouter patient
                </Link>
              )
            : undefined
        }
        subtitle={
          isFamilyView
            ? 'Consultation des patients lies au compte famille.'
            : 'Recherche rapide, filtres et ouverture de fiche en 1 clic.'
        }
        title="Patients"
      />

      <SectionCard title="Liste patients">
        <div className="patients-toolbar">
          <label className="field-block">
            <span>Recherche</span>
            <input
              onChange={(event) => setSearchTerm(event.target.value)}
              placeholder="Rechercher (ID, nom, CIN, age)..."
              type="search"
              value={searchTerm}
            />
          </label>

          <div className="chip-row" role="radiogroup" aria-label="Filtre statut">
            {statusFilters.map((filter) => (
              <button
                aria-checked={statusFilter === filter.value}
                className={
                  statusFilter === filter.value
                    ? 'chip-button is-selected'
                    : 'chip-button'
                }
                key={filter.value}
                onClick={() => setStatusFilter(filter.value)}
                role="radio"
                type="button"
              >
                {filter.label}
              </button>
            ))}
          </div>
        </div>

        {isLoading && <p className="state-text">Chargement des patients...</p>}

        {!isLoading && error && (
          <EmptyState
            iconLabel="ERR"
            message={error}
            title="Chargement impossible"
          />
        )}

        {!isLoading && !error && visiblePatients.length === 0 && (
          <EmptyState
            iconLabel="VIDE"
            message="Aucun patient ne correspond a vos criteres."
            title="Aucun patient"
          />
        )}

        {!isLoading && !error && visiblePatients.length > 0 && (
          <div className="patients-grid">
            {visiblePatients.map((patient) => (
              <article className="patient-overview-card" key={patient.id}>
                <div className="patient-overview-head">
                  <div>
                    <h4>
                      {patient.first_name} {patient.last_name}
                    </h4>
                    <p className="patient-overview-code">
                      ID {patient.patient_code}
                    </p>
                  </div>
                  <StatusBadge
                    label={getStatusLabel(patient.computedStatus)}
                    tone={getStatusTone(patient.computedStatus)}
                  />
                </div>

                <p className="patient-overview-fact">
                  <strong>Age:</strong> {patient.age} ans
                </p>
                <p className="patient-overview-fact">
                  <strong>CIN:</strong> {patient.cin}
                </p>
                <p className="patient-overview-fact">
                  <strong>Date naissance:</strong>{' '}
                  {formatBirthDate(patient.birth_date)}
                </p>

                <div className="patient-overview-actions">
                  <Link className="btn btn-primary btn-inline" to={`/patients/${patient.id}`}>
                    Voir fiche
                  </Link>
                </div>
              </article>
            ))}
          </div>
        )}
      </SectionCard>
    </DoctorShellLayout>
  )
}
