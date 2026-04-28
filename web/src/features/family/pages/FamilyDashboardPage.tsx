import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'

import { useAuth } from '../../../core/auth/useAuth'
import { getFamilyPatients } from '../../patients/api/patientsApi'
import type { Patient } from '../../patients/types'
import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { EmptyState } from '../../../shared/ui/EmptyState'
import { SectionCard } from '../../../shared/ui/SectionCard'
import { StatusBadge } from '../../../shared/ui/StatusBadge'

function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return 'Impossible de charger le dashboard famille.'
}

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

function getStatusLabel(status: Patient['status']): string {
  if (status === 'suivi') return 'Suivi'
  if (status === 'a_verifier') return 'A verifier'
  return 'Nouveau'
}

function getStatusTone(
  status: Patient['status'],
): 'neutral' | 'primary' | 'warning' {
  if (status === 'suivi') return 'neutral'
  if (status === 'a_verifier') return 'warning'
  return 'primary'
}

export function FamilyDashboardPage() {
  const { user } = useAuth()
  const [patients, setPatients] = useState<Patient[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const firstPatient = patients[0] ?? null

  const greeting = useMemo(() => {
    const firstName = user?.first_name?.trim() ?? ''
    const lastName = user?.last_name?.trim() ?? ''
    if (firstName || lastName) {
      return `Bonjour ${firstName} ${lastName}`.trim()
    }
    return 'Bonjour'
  }, [user?.first_name, user?.last_name])

  const loadPatients = useCallback(async () => {
    if (!user) {
      setPatients([])
      setError('Utilisateur non connecte.')
      setIsLoading(false)
      return
    }

    setIsLoading(true)
    setError(null)
    try {
      const items = await getFamilyPatients(user.id)
      setPatients(items)
    } catch (loadError) {
      setPatients([])
      setError(getErrorMessage(loadError))
    } finally {
      setIsLoading(false)
    }
  }, [user])

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void loadPatients()
  }, [loadPatients])

  return (
    <DoctorShellLayout title="Dashboard famille">
      <AppHeader
        actions={
          <div className="header-action-row">
            <Link className="btn btn-primary" to="/patients">
              Voir patients
            </Link>
            <Link className="btn btn-outline" to="/alerts">
              Alertes
            </Link>
            <Link className="btn btn-outline" to="/location">
              Localisation
            </Link>
            {firstPatient && (
              <Link
                className="btn btn-outline"
                to={`/patients/${firstPatient.id}`}
              >
                Traitements
              </Link>
            )}
          </div>
        }
        subtitle="Vue famille en lecture et suivi des informations du patient."
        title={greeting}
      />

      {error && (
        <div className="error-banner" role="alert">
          <p>{error}</p>
          <button
            className="btn btn-text"
            onClick={() => {
              void loadPatients()
            }}
            type="button"
          >
            Reessayer
          </button>
        </div>
      )}

      <SectionCard
        action={
          <StatusBadge
            label={`${patients.length} patient${patients.length > 1 ? 's' : ''}`}
            tone="primary"
          />
        }
        title="Patients lies"
      >
        {isLoading && <p className="state-text">Chargement des patients...</p>}

        {!isLoading && !error && patients.length === 0 && (
          <EmptyState
            iconLabel="VIDE"
            message="Aucun patient n est associe a ce compte famille."
            title="Aucun patient"
          />
        )}

        {!isLoading && !error && patients.length > 0 && (
          <div className="patients-grid">
            {patients.map((patient) => (
              <article className="patient-overview-card" key={patient.id}>
                <div className="patient-overview-head">
                  <div>
                    <h4>
                      {patient.first_name} {patient.last_name}
                    </h4>
                    <p className="patient-overview-code">
                      ID {patient.patient_code || `P-${patient.id}`}
                    </p>
                  </div>
                  <StatusBadge
                    label={getStatusLabel(patient.status)}
                    tone={getStatusTone(patient.status)}
                  />
                </div>

                <p className="patient-overview-fact">
                  <strong>Age:</strong> {getAgeFromBirthDate(patient.birth_date)} ans
                </p>
                <p className="patient-overview-fact">
                  <strong>CIN:</strong> {patient.cin}
                </p>
                <p className="patient-overview-fact">
                  <strong>Date naissance:</strong> {formatBirthDate(patient.birth_date)}
                </p>

                <div className="patient-overview-actions">
                  <Link className="btn btn-primary btn-inline" to={`/patients/${patient.id}`}>
                    Ouvrir dossier
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
