import axios from 'axios'

import { AUTH_UNAUTHORIZED_EVENT, getStoredToken } from '../auth/authStorage'

const DEFAULT_API_BASE_URL = 'http://127.0.0.1:8000'

const resolvedBaseUrl =
  import.meta.env.VITE_API_BASE_URL?.trim() || DEFAULT_API_BASE_URL

export interface ApiError {
  status?: number
  message: string
  data?: unknown
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function extractErrorMessage(data: unknown, status?: number): string {
  if (typeof data === 'string' && data.trim().length > 0) {
    return data
  }

  if (isRecord(data)) {
    const detail = data.detail
    if (typeof detail === 'string' && detail.trim().length > 0) {
      return detail
    }

    if (Array.isArray(detail) && detail.length > 0) {
      const first = detail[0]
      if (isRecord(first) && typeof first.msg === 'string') {
        return first.msg
      }
    }
  }

  if (status === 401) return 'Session expiree, veuillez vous reconnecter.'
  if (status === 403) return 'Acces refuse.'
  if (status === 404) return 'Ressource introuvable.'
  if (status === 422) return 'Requete invalide.'
  if (status && status >= 500) return 'Erreur serveur.'
  return 'Erreur reseau.'
}

const axiosClient = axios.create({
  baseURL: resolvedBaseUrl,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
})

axiosClient.interceptors.request.use((config) => {
  const token = getStoredToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

axiosClient.interceptors.response.use(
  (response) => response,
  (error: unknown) => {
    if (!axios.isAxiosError(error)) {
      const unknownError: ApiError = { message: 'Erreur reseau inattendue.' }
      return Promise.reject(unknownError)
    }

    const status = error.response?.status
    const data = error.response?.data

    const apiError: ApiError = {
      status,
      data,
      message: extractErrorMessage(data, status),
    }

    if (status === 401 && typeof window !== 'undefined') {
      window.dispatchEvent(new Event(AUTH_UNAUTHORIZED_EVENT))
    }

    return Promise.reject(apiError)
  },
)

export function isApiError(error: unknown): error is ApiError {
  return (
    isRecord(error) &&
    typeof error.message === 'string' &&
    (!('status' in error) || typeof error.status === 'number')
  )
}

export default axiosClient
