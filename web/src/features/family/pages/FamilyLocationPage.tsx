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
  getPatientLastLocation,
} from '../../patients/api/patientsApi'
import type { Patient, PatientLocation } from '../../patients/types'

function formatDateTime(value: string): string {
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return value
  }
  return parsed.toLocaleString('fr-FR')
}

function formatCoordinates(latitude: number, longitude: number): string {
  return `${latitude.toFixed(6)}, ${longitude.toFixed(6)}`
}

function getErrorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return fallback
}

export function FamilyLocationPage() {
  const { user } = useAuth()
  const [patients, setPatients] = useState<Patient[]>([])
  const [selectedPatientId, setSelectedPatientId] = useState<number | null>(null)
  const [location, setLocation] = useState<PatientLocation | null>(null)
  const [isLoadingPatients, setIsLoadingPatients] = useState(true)
  const [isLoadingLocation, setIsLoadingLocation] = useState(false)
  const [patientsError, setPatientsError] = useState<string | null>(null)
  const [locationError, setLocationError] = useState<string | null>(null)

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

  const loadLocation = useCallback(async () => {
    if (!selectedPatientId) {
      setLocation(null)
      setLocationError(null)
      setIsLoadingLocation(false)
      return
    }

    setIsLoadingLocation(true)
    setLocationError(null)
    try {
      const item = await getPatientLastLocation(selectedPatientId)
      setLocation(item)
    } catch (loadError) {
      setLocation(null)
      setLocationError(
        getErrorMessage(loadError, 'Impossible de charger la localisation.'),
      )
    } finally {
      setIsLoadingLocation(false)
    }
  }, [selectedPatientId])

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void loadPatients()
  }, [loadPatients])

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void loadLocation()
  }, [loadLocation])

  return (
    <DoctorShellLayout title="Localisation">
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
        subtitle="Vue famille sans carte interactive."
        title="Derniere position patient"
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

      <SectionCard title="Derniere localisation">
        {isLoadingLocation && <p className="state-text">Chargement...</p>}

        {!isLoadingLocation && locationError && (
          <EmptyState
            iconLabel="ERR"
            message={locationError}
            title="Chargement impossible"
          />
        )}

        {!isLoadingLocation && !locationError && !location && (
          <EmptyState
            iconLabel="GPS"
            message="Aucune position n a encore ete enregistree pour ce patient."
            title="Aucune localisation disponible"
          />
        )}

        {!isLoadingLocation && !locationError && location && (
          <div className="record-list">
            <article className="record-card">
              <div className="record-head">
                <strong>Position transmise</strong>
                <StatusBadge label="Disponible" tone="primary" />
              </div>
              <p className="record-text">
                {formatCoordinates(location.latitude, location.longitude)}
              </p>
              <p className="record-subtext">
                Transmise le {formatDateTime(location.recorded_at)}
              </p>
            </article>
          </div>
        )}
      </SectionCard>
    </DoctorShellLayout>
  )
}
