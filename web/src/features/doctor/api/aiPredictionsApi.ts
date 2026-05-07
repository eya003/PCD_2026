import { isApiError } from '../../../core/api/axiosClient'
import axiosClient from '../../../core/api/axiosClient'

export interface MriPredictionResult {
  diagnosis_id: number
  patient_id: number
  questionnaire_id: number | null
  predicted_class: 'AD' | 'CN'
  confidence_score: number
  prob_ad: number
  cnn_prob_AD: number
  cnn_pred_061: number
  threshold: number
  message: string
}

interface PredictMriPayload {
  patientId: number
  mriFile: File
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

function asNullableNumber(value: unknown): number | null {
  if (value === null || value === undefined) {
    return null
  }
  return asNumber(value)
}

function asString(value: unknown): string | null {
  if (typeof value === 'string') {
    return value
  }
  return null
}

function asPredictedClass(value: unknown): 'AD' | 'CN' | null {
  if (value === 'AD' || value === 'CN') {
    return value
  }
  return null
}

function parseMriPredictionResult(data: unknown): MriPredictionResult {
  if (!isRecord(data)) {
    throw new Error('Format de reponse prediction IA invalide.')
  }

  const diagnosisId = asNumber(data.diagnosis_id)
  const patientId = asNumber(data.patient_id)
  const questionnaireId = asNullableNumber(data.questionnaire_id)
  const predictedClass = asPredictedClass(data.predicted_class)
  const confidenceScore = asNumber(data.confidence_score)
  const probAd = asNumber(data.prob_ad)
  const cnnProbAd = asNumber(data.cnn_prob_AD)
  const cnnPred061 = asNumber(data.cnn_pred_061)
  const threshold = asNumber(data.threshold)
  const message = asString(data.message)

  if (
    diagnosisId === null ||
    patientId === null ||
    predictedClass === null ||
    confidenceScore === null ||
    probAd === null ||
    cnnProbAd === null ||
    cnnPred061 === null ||
    threshold === null ||
    message === null
  ) {
    throw new Error('Donnees prediction IA incompletes.')
  }

  return {
    diagnosis_id: diagnosisId,
    patient_id: patientId,
    questionnaire_id: questionnaireId,
    predicted_class: predictedClass,
    confidence_score: confidenceScore,
    prob_ad: probAd,
    cnn_prob_AD: cnnProbAd,
    cnn_pred_061: cnnPred061,
    threshold,
    message,
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

export async function predictMri(
  payload: PredictMriPayload,
): Promise<MriPredictionResult> {
  const formData = new FormData()
  formData.append('patient_id', String(payload.patientId))
  formData.append('mri_file', payload.mriFile)

  try {
    const response = await axiosClient.post<unknown>('/ai/predict-mri', formData, {
      timeout: 360000,
    })
    return parseMriPredictionResult(response.data)
  } catch (error) {
    throw new Error(
      resolveErrorMessage(error, 'Impossible de lancer la prediction IA MRI.'),
      {
        cause: error,
      },
    )
  }
}
