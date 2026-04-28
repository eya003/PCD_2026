import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'

import { useAuth } from '../../../core/auth/useAuth'
import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { EmptyState } from '../../../shared/ui/EmptyState'
import { SectionCard } from '../../../shared/ui/SectionCard'
import { StatusBadge } from '../../../shared/ui/StatusBadge'
import {
  getFamilyPatients,
  getPatientAlerts,
} from '../../patients/api/patientsApi'
import type { Patient, PatientAlert } from '../../patients/types'

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

function getErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return fallback
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

export function FamilyAlertsPage() {
  const { user } = useAuth()
  const [patients, setPatients] = useState<Patient[]>([])
  const [selectedPatientId, setSelectedPatientId] = useState<number | null>(null)
  const [alerts, setAlerts] = useState<PatientAlert[]>([])
  const [isLoadingPatients, setIsLoadingPatients] = useState(true)
  const [isLoadingAlerts, setIsLoadingAlerts] = useState(false)
  const [patientsError, setPatientsError] = useState<string | null>(null)
  const [alertsError, setAlertsError] = useState<string | null>(null)

  const selectedPatient = useMemo(() => {
    if (!selectedPatientId) {
      return null
    }
    return patients.find((patient) => patient.id === selectedPatientId) ?? null
  }, [patients, selectedPatientId])

  const loadPatients = useCallback(async () => {
    if (!user) {
      setPatients([])
      setSelectedPatientId(null)
      setPatientsError('Utilisateur non connecte.')
      setIsLoadingPatients(false)
      return
    }

    setIsLoadingPatients(true)
    setPatientsError(null)

    try {
      const items = await getFamilyPatients(user.id)
      setPatients(items)
      setSelectedPatientId((currentId) => {
        if (currentId && items.some((item) => item.id === currentId)) {
          return currentId
        }
        return items[0]?.id ?? null
      })
    } catch (loadError) {
      setPatients([])
      setSelectedPatientId(null)
      setPatientsError(
        getErrorMessage(loadError, 'Impossible de charger les patients lies.'),
      )
    } finally {
      setIsLoadingPatients(false)
    }
  }, [user])

  const loadAlerts = useCallback(async () => {
    if (!selectedPatientId) {
      setAlerts([])
      setAlertsError(null)
      setIsLoadingAlerts(false)
      return
    }

    setIsLoadingAlerts(true)
    setAlertsError(null)
    try {
      const items = await getPatientAlerts(selectedPatientId)
      setAlerts(items)
    } catch (loadError) {
      setAlerts([])
      setAlertsError(getErrorMessage(loadError, 'Impossible de charger les alertes.'))
    } finally {
      setIsLoadingAlerts(false)
    }
  }, [selectedPatientId])

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void loadPatients()
  }, [loadPatients])

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void loadAlerts()
  }, [loadAlerts])

  return (
    <DoctorShellLayout title="Alertes">
      <AppHeader
        actions={
          <button
            className="btn btn-outline"
            onClick={() => {
              void loadPatients()
            }}
            type="button"
          >
            Actualiser
          </button>
        }
        subtitle="Mode famille en lecture seule."
        title="Alertes patient"
      />

      <SectionCard title="Patient">
        {isLoadingPatients && <p className="state-text">Chargement des patients...</p>}

        {!isLoadingPatients && patientsError && (
          <EmptyState
            iconLabel="ERR"
            message={patientsError}
            title="Chargement impossible"
          />
        )}

        {!isLoadingPatients && !patientsError && patients.length === 0 && (
          <EmptyState
            iconLabel="VIDE"
            message="Aucun patient n est associe a ce compte famille."
            title="Aucun patient"
          />
        )}

        {!isLoadingPatients && !patientsError && patients.length > 0 && (
          <div className="patients-toolbar">
            <label className="field-block">
              <span>Selectionner un patient</span>
              <select
                className="input-control"
                onChange={(event) =>
                  setSelectedPatientId(Number.parseInt(event.target.value, 10))
                }
                value={selectedPatientId ?? ''}
              >
                {patients.map((patient) => (
                  <option key={patient.id} value={patient.id}>
                    {patient.first_name} {patient.last_name}
                  </option>
                ))}
              </select>
            </label>

            {selectedPatient && (
              <div className="header-action-row">
                <Link className="btn btn-primary" to={`/patients/${selectedPatient.id}`}>
                  Ouvrir dossier
                </Link>
              </div>
            )}
          </div>
        )}
      </SectionCard>

      <SectionCard title="Liste alertes">
        {isLoadingAlerts && <p className="state-text">Chargement des alertes...</p>}

        {!isLoadingAlerts && alertsError && (
          <EmptyState
            iconLabel="ERR"
            message={alertsError}
            title="Chargement impossible"
          />
        )}

        {!isLoadingAlerts && !alertsError && selectedPatientId && alerts.length === 0 && (
          <EmptyState
            iconLabel="VIDE"
            message="Aucune alerte enregistree pour ce patient."
            title="Aucune alerte"
          />
        )}

        {!isLoadingAlerts && !alertsError && alerts.length > 0 && (
          <div className="record-list">
            {alerts.map((alert) => (
              <article
                className={alert.is_read ? 'record-card alert-item' : 'record-card alert-item is-unread'}
                key={alert.id}
              >
                <div className="record-head">
                  <StatusBadge
                    label={getAlertTypeLabel(alert.type)}
                    tone={getAlertTypeTone(alert.type)}
                  />
                  <StatusBadge
                    label={alert.is_read ? 'Lue' : 'Non lue'}
                    tone={alert.is_read ? 'success' : 'warning'}
                  />
                </div>
                <p className="record-text">{alert.message}</p>
                <p className="record-subtext">Date: {formatDateTime(alert.created_at)}</p>
              </article>
            ))}
          </div>
        )}
      </SectionCard>
    </DoctorShellLayout>
  )
}
