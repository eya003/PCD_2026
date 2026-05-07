import {
  type ChangeEvent,
  type FormEvent,
  useEffect,
  useMemo,
  useState,
} from 'react'

import { useAuth } from '../../../core/auth/useAuth'
import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { SectionCard } from '../../../shared/ui/SectionCard'
import { StatusBadge } from '../../../shared/ui/StatusBadge'
import { getDoctorPatients } from '../../patients/api/patientsApi'
import type { Patient } from '../../patients/types'
import { predictMri, type MriPredictionResult } from '../api/aiPredictionsApi'

const ACCEPTED_MRI_EXTENSIONS = '.nii,.nii.gz'
const MAX_PATIENT_RESULTS = 8

function isAcceptedMriFile(file: File): boolean {
  const fileName = file.name.toLowerCase()
  return fileName.endsWith('.nii') || fileName.endsWith('.nii.gz')
}

function formatPercent(value: number): string {
  return `${(value * 100).toFixed(2)} %`
}

function formatScore(value: number): string {
  return value.toFixed(3)
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return 'Impossible de lancer la prediction IA MRI.'
}

function getPatientLoadErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return 'Impossible de charger les patients.'
}

function getPatientCode(patient: Patient): string {
  const normalizedCode = patient.patient_code.trim()
  return normalizedCode.length > 0 ? normalizedCode : `P-${patient.id}`
}

function getPatientName(patient: Patient): string {
  return `${patient.first_name} ${patient.last_name}`.trim()
}

function normalizeSearchValue(value: string): string {
  return value.trim().toLowerCase()
}

function patientMatchesQuery(patient: Patient, query: string): boolean {
  const normalizedQuery = normalizeSearchValue(query)
  if (!normalizedQuery) {
    return false
  }

  const firstName = normalizeSearchValue(patient.first_name)
  const lastName = normalizeSearchValue(patient.last_name)
  const fullName = normalizeSearchValue(`${patient.first_name} ${patient.last_name}`)
  const reversedName = normalizeSearchValue(`${patient.last_name} ${patient.first_name}`)
  const cin = normalizeSearchValue(patient.cin)
  const patientCode = normalizeSearchValue(getPatientCode(patient))

  return (
    firstName.includes(normalizedQuery) ||
    lastName.includes(normalizedQuery) ||
    fullName.includes(normalizedQuery) ||
    reversedName.includes(normalizedQuery) ||
    cin.includes(normalizedQuery) ||
    patientCode.includes(normalizedQuery)
  )
}

export function DoctorAiPage() {
  const { user } = useAuth()
  const [patients, setPatients] = useState<Patient[]>([])
  const [isLoadingPatients, setIsLoadingPatients] = useState(true)
  const [patientLoadError, setPatientLoadError] = useState<string | null>(null)
  const [patientSearch, setPatientSearch] = useState('')
  const [selectedPatient, setSelectedPatient] = useState<Patient | null>(null)
  const [mriFile, setMriFile] = useState<File | null>(null)
  const [result, setResult] = useState<MriPredictionResult | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  useEffect(() => {
    let isActive = true

    async function loadPatients() {
      if (!user || user.role !== 'doctor') {
        if (isActive) {
          setPatients([])
          setPatientLoadError('Action reservee au medecin.')
          setIsLoadingPatients(false)
        }
        return
      }

      if (isActive) {
        setIsLoadingPatients(true)
        setPatientLoadError(null)
      }

      try {
        const doctorPatients = await getDoctorPatients(user.id)
        if (isActive) {
          setPatients(doctorPatients)
        }
      } catch (loadError) {
        if (isActive) {
          setPatients([])
          setPatientLoadError(getPatientLoadErrorMessage(loadError))
        }
      } finally {
        if (isActive) {
          setIsLoadingPatients(false)
        }
      }
    }

    void loadPatients()

    return () => {
      isActive = false
    }
  }, [user])

  const patientResults = useMemo(() => {
    return patients
      .filter((patient) => patientMatchesQuery(patient, patientSearch))
      .slice(0, MAX_PATIENT_RESULTS)
  }, [patientSearch, patients])

  const hasPatientQuery = patientSearch.trim().length > 0

  function handlePatientSearchChange(event: ChangeEvent<HTMLInputElement>) {
    setPatientSearch(event.target.value)
    setSelectedPatient(null)
    setResult(null)
    setError(null)
  }

  function handleSelectPatient(patient: Patient) {
    setSelectedPatient(patient)
    setPatientSearch(`${getPatientName(patient)} - ${getPatientCode(patient)}`)
    setResult(null)
    setError(null)
  }

  function handleClearSelectedPatient() {
    setSelectedPatient(null)
    setPatientSearch('')
    setResult(null)
    setError(null)
  }

  function handleFileChange(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0] ?? null
    setMriFile(file)
    setResult(null)
    setError(null)
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setResult(null)

    if (!selectedPatient) {
      setError('Veuillez sélectionner un patient.')
      return
    }

    if (!mriFile) {
      setError('Veuillez selectionner un fichier IRM.')
      return
    }

    if (!isAcceptedMriFile(mriFile)) {
      setError('Format invalide. Le fichier doit etre .nii ou .nii.gz.')
      return
    }

    setIsSubmitting(true)
    try {
      const prediction = await predictMri({
        patientId: selectedPatient.id,
        mriFile,
      })
      setResult(prediction)
    } catch (submitError) {
      setError(getErrorMessage(submitError))
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <DoctorShellLayout title="Module IA">
      <AppHeader
        subtitle="Test du modele IA a partir d'une IRM cerebrale NIfTI."
        title="Prediction Alzheimer par IRM"
      />

      <SectionCard title="Avertissement medical">
        <p className="section-paragraph">
          Ce resultat est une aide au diagnostic et ne remplace pas l'avis medical
          du medecin.
        </p>
      </SectionCard>

      <SectionCard title="Nouvelle prediction">
        <form className="auth-form" onSubmit={handleSubmit}>
          <label className="field-block">
            <span>Patient</span>
            <input
              className="input-control"
              disabled={isSubmitting || isLoadingPatients}
              onChange={handlePatientSearchChange}
              placeholder="Rechercher par nom, prenom, CIN ou code patient..."
              type="search"
              value={patientSearch}
            />
          </label>

          {isLoadingPatients && (
            <p className="state-text" role="status">
              Chargement des patients...
            </p>
          )}

          {patientLoadError && (
            <div className="error-banner" role="alert">
              <p>{patientLoadError}</p>
            </div>
          )}

          {!selectedPatient && hasPatientQuery && !patientLoadError && (
            <div className="record-list">
              {patientResults.length === 0 && !isLoadingPatients && (
                <p className="state-text">Aucun patient trouvé.</p>
              )}

              {patientResults.map((patient) => (
                <article className="record-card" key={patient.id}>
                  <div className="record-head">
                    <strong>{getPatientName(patient)}</strong>
                    <span className="record-date">ID {getPatientCode(patient)}</span>
                  </div>
                  <p className="record-text">CIN: {patient.cin}</p>
                  <div className="dialog-actions">
                    <button
                      className="btn btn-outline btn-inline"
                      disabled={isSubmitting}
                      onClick={() => handleSelectPatient(patient)}
                      type="button"
                    >
                      Selectionner
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}

          {selectedPatient && (
            <article className="record-card">
              <div className="record-head">
                <strong>Patient choisi</strong>
                <StatusBadge label="Selectionne" tone="success" />
              </div>
              <p className="record-text">
                {selectedPatient.last_name} {selectedPatient.first_name}
              </p>
              <p className="record-subtext">CIN: {selectedPatient.cin}</p>
              <p className="record-subtext">
                Code patient: {getPatientCode(selectedPatient)}
              </p>
              <div className="dialog-actions">
                <button
                  className="btn btn-outline btn-inline"
                  disabled={isSubmitting}
                  onClick={handleClearSelectedPatient}
                  type="button"
                >
                  Changer patient
                </button>
              </div>
            </article>
          )}

          <label className="field-block">
            <span>Fichier IRM</span>
            <input
              accept={ACCEPTED_MRI_EXTENSIONS}
              className="input-control"
              disabled={isSubmitting}
              onChange={handleFileChange}
              type="file"
            />
          </label>

          <p className="record-subtext">
            Formats acceptes: .nii et .nii.gz. L'analyse peut prendre plusieurs
            minutes selon la taille du fichier et la charge du backend.
          </p>

          {error && (
            <div className="error-banner" role="alert">
              <p>{error}</p>
            </div>
          )}

          {isSubmitting && (
            <p className="state-text" role="status">
              Analyse IA en cours...
            </p>
          )}

          <div className="dialog-actions">
            <button
              className="btn btn-primary"
              disabled={isSubmitting}
              type="submit"
            >
              {isSubmitting ? 'Analyse en cours...' : 'Lancer la prediction'}
            </button>
          </div>
        </form>
      </SectionCard>

      {result && (
        <SectionCard title="Resultat de prediction">
          <div className="record-list">
            <article className="record-card">
              <div className="record-head">
                <strong>Classe predite</strong>
                <StatusBadge
                  label={result.predicted_class}
                  tone={result.predicted_class === 'AD' ? 'warning' : 'success'}
                />
              </div>
              <p className="record-subtext">Message: {result.message}</p>
            </article>

            <article className="record-card">
              <div className="record-head">
                <strong>Diagnostic ID</strong>
                <span className="record-date">{result.diagnosis_id}</span>
              </div>
              <p className="record-text">Patient ID: {result.patient_id}</p>
              <p className="record-subtext">
                Questionnaire ID: {result.questionnaire_id ?? 'Aucun'}
              </p>
            </article>

            <article className="record-card">
              <div className="record-head">
                <strong>Scores modele final</strong>
              </div>
              <p className="record-text">
                Score de confiance: {formatPercent(result.confidence_score)}
              </p>
              <p className="record-text">
                Probabilite AD: {formatPercent(result.prob_ad)}
              </p>
              <p className="record-subtext">
                Seuil du modele final: {formatScore(result.threshold)}
              </p>
            </article>

            <article className="record-card">
              <div className="record-head">
                <strong>Sortie CNN</strong>
              </div>
              <p className="record-text">
                Probabilite CNN AD: {formatPercent(result.cnn_prob_AD)}
              </p>
              <p className="record-subtext">
                Prediction CNN seuil 0.61: {formatScore(result.cnn_pred_061)}
              </p>
            </article>
          </div>
        </SectionCard>
      )}
    </DoctorShellLayout>
  )
}
