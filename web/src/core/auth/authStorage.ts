import type { AuthUser } from './types'

export const AUTH_TOKEN_STORAGE_KEY = 'pcd.auth.token'
export const AUTH_USER_STORAGE_KEY = 'pcd.auth.user'
export const AUTH_UNAUTHORIZED_EVENT = 'pcd:auth:unauthorized'

export function getStoredToken(): string | null {
  return localStorage.getItem(AUTH_TOKEN_STORAGE_KEY)
}

export function getStoredUser(): AuthUser | null {
  const raw = localStorage.getItem(AUTH_USER_STORAGE_KEY)
  if (!raw) {
    return null
  }

  try {
    const parsed = JSON.parse(raw) as AuthUser
    if (
      typeof parsed.id === 'number' &&
      typeof parsed.first_name === 'string' &&
      typeof parsed.last_name === 'string' &&
      typeof parsed.cin === 'string' &&
      typeof parsed.email === 'string' &&
      (parsed.role === 'doctor' || parsed.role === 'family')
    ) {
      return parsed
    }
  } catch {
    // Ignore malformed local session.
  }

  return null
}

export function setStoredSession(token: string, user: AuthUser): void {
  localStorage.setItem(AUTH_TOKEN_STORAGE_KEY, token)
  localStorage.setItem(AUTH_USER_STORAGE_KEY, JSON.stringify(user))
}

export function clearStoredSession(): void {
  localStorage.removeItem(AUTH_TOKEN_STORAGE_KEY)
  localStorage.removeItem(AUTH_USER_STORAGE_KEY)
}
