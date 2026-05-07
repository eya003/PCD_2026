import { EmptyState } from '../../../shared/ui/EmptyState'
import { SectionCard } from '../../../shared/ui/SectionCard'
import { StatusBadge } from '../../../shared/ui/StatusBadge'
import type { Diagnosis, PatientDoctorSummary } from '../types'

interface PatientAiResultsCardProps {
  diagnoses: Diagnosis[]
  error: string | null
  isLoading: boolean
  doctors: PatientDoctorSummary[]
}

interface ParsedAiDetails {
  opinion: string | null
  probAd: number | null
  cnnProbAd: number | null
  cnnPred061: number | null
  threshold: number | null
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function asNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value)
    if (Number.isFinite(parsed)) {
      return parsed
    }
  }
  return null
}

function asString(value: unknown): string | null {
  if (typeof value === 'string' && value.trim().length > 0) {
    return value
  }
  return null
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

function formatPercent(value: number | null): string | null {
  if (value === null) {
    return null
  }
  return `${(value * 100).toFixed(2)} %`
}

function formatNumber(value: number | null): string | null {
  if (value === null) {
    return null
  }
  return value.toFixed(3)
}

function getPredictionTone(modelResult: string): 'neutral' | 'success' | 'warning' {
  const normalized = modelResult.trim().toUpperCase()
  if (normalized === 'AD') {
    return 'warning'
  }
  if (normalized === 'CN') {
    return 'success'
  }
  return 'neutral'
}

function parseAiDetails(value: string | null): ParsedAiDetails {
  if (!value || value.trim().length === 0) {
    return {
      opinion: null,
      probAd: null,
      cnnProbAd: null,
      cnnPred061: null,
      threshold: null,
    }
  }

  try {
    const parsed = JSON.parse(value) as unknown
    if (!isRecord(parsed)) {
      return {
        opinion: value,
        probAd: null,
        cnnProbAd: null,
        cnnPred061: null,
        threshold: null,
      }
    }

    return {
      opinion:
        asString(parsed.final_medical_opinion) ??
        asString(parsed.medical_opinion) ??
        asString(parsed.opinion),
      probAd: asNumber(parsed.prob_ad),
      cnnProbAd: asNumber(parsed.cnn_prob_AD),
      cnnPred061: asNumber(parsed.cnn_pred_061),
      threshold: asNumber(parsed.threshold),
    }
  } catch {
    return {
      opinion: value,
      probAd: null,
      cnnProbAd: null,
      cnnPred061: null,
      threshold: null,
    }
  }
}

function resolveDoctorLabel(
  doctorId: number | null,
  doctors: PatientDoctorSummary[],
): string {
  if (doctorId === null) {
    return 'Medecin non renseigne'
  }

  const doctor = doctors.find((item) => item.id === doctorId)
  if (!doctor) {
    return `Medecin #${doctorId}`
  }

  return `${doctor.first_name} ${doctor.last_name}`.trim() || `Medecin #${doctorId}`
}

export function PatientAiResultsCard({
  diagnoses,
  error,
  isLoading,
  doctors,
}: PatientAiResultsCardProps) {
  return (
    <SectionCard title="Résultats IA">
      <p className="section-paragraph">
        Ce résultat est une aide au diagnostic et ne remplace pas l'avis médical
        du médecin.
      </p>

      {isLoading && <p className="state-text">Chargement...</p>}

      {!isLoading && error && (
        <EmptyState
          iconLabel="ERR"
          message={error}
          title="Chargement impossible"
        />
      )}

      {!isLoading && !error && diagnoses.length === 0 && (
        <EmptyState
          iconLabel="IA"
          message="Aucun résultat IA disponible pour ce patient."
          title="Aucun résultat IA"
        />
      )}

      {!isLoading && !error && diagnoses.length > 0 && (
        <div className="record-list">
          {diagnoses.map((diagnosis) => {
            const aiDetails = parseAiDetails(diagnosis.final_medical_opinion)
            const confidence = formatPercent(diagnosis.confidence_score)
            const probAd = formatPercent(aiDetails.probAd)
            const cnnProbAd = formatPercent(aiDetails.cnnProbAd)
            const cnnPred061 = formatNumber(aiDetails.cnnPred061)
            const threshold = formatNumber(aiDetails.threshold)

            return (
              <article className="record-card" key={`ai-result-${diagnosis.id}`}>
                <div className="record-head">
                  <strong>Diagnostic IA #{diagnosis.id}</strong>
                  <StatusBadge
                    label={diagnosis.model_result}
                    tone={getPredictionTone(diagnosis.model_result)}
                  />
                </div>

                <p className="record-text">
                  Classe prédite: {diagnosis.model_result}
                </p>
                <p className="record-subtext">
                  Date: {formatDateTime(diagnosis.created_at)}
                </p>
                <p className="record-subtext">
                  Medecin: {resolveDoctorLabel(diagnosis.doctor_id, doctors)}
                </p>

                {confidence && (
                  <p className="record-subtext">
                    Score de confiance: {confidence}
                  </p>
                )}

                {aiDetails.opinion && (
                  <p className="record-subtext">
                    Avis medical final: {aiDetails.opinion}
                  </p>
                )}

                {(probAd || cnnProbAd || cnnPred061 || threshold) && (
                  <p className="record-subtext">
                    {[
                      probAd ? `Probabilite AD: ${probAd}` : null,
                      cnnProbAd ? `CNN AD: ${cnnProbAd}` : null,
                      cnnPred061 ? `CNN seuil 0.61: ${cnnPred061}` : null,
                      threshold ? `Seuil final: ${threshold}` : null,
                    ]
                      .filter(Boolean)
                      .join(' - ')}
                  </p>
                )}
              </article>
            )
          })}
        </div>
      )}
    </SectionCard>
  )
}
