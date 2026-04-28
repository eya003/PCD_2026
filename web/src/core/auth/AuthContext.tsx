import type { PropsWithChildren } from 'react'
import {
  useCallback,
  useEffect,
  useMemo,
  useState,
} from 'react'

import axiosClient, { isApiError } from '../api/axiosClient'
import {
  AUTH_UNAUTHORIZED_EVENT,
  clearStoredSession,
  getStoredToken,
  getStoredUser,
  setStoredSession,
} from './authStorage'
import { AuthContext, type AuthContextValue } from './authContextStore'
import type {
  AuthUser,
  LoginResponse,
  RegisterDoctorPayload,
  RegisterDoctorResult,
} from './types'

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function parseAuthUser(data: unknown): AuthUser | null {
  if (!isRecord(data)) {
    return null
  }

  const id = data.id
  const firstName = data.first_name
  const lastName = data.last_name
  const cin = data.cin
  const email = data.email
  const role = data.role

  if (
    typeof id === 'number' &&
    typeof firstName === 'string' &&
    typeof lastName === 'string' &&
    typeof cin === 'string' &&
    typeof email === 'string' &&
    (role === 'doctor' || role === 'family')
  ) {
    return {
      id,
      first_name: firstName,
      last_name: lastName,
      cin,
      email,
      role,
    }
  }

  return null
}

async function fetchCurrentUser(token: string): Promise<AuthUser> {
  const response = await axiosClient.get<AuthUser>('/auth/me', {
    headers: { Authorization: `Bearer ${token}` },
  })
  return response.data
}

export function AuthProvider({ children }: PropsWithChildren) {
  const [user, setUser] = useState<AuthUser | null>(getStoredUser())
  const [token, setToken] = useState<string | null>(getStoredToken())
  const [isLoading, setIsLoading] = useState(true)

  const logout = useCallback(() => {
    clearStoredSession()
    setToken(null)
    setUser(null)
  }, [])

  const restoreSession = useCallback(async () => {
    const currentToken = getStoredToken()
    if (!currentToken) {
      setToken(null)
      setUser(null)
      setIsLoading(false)
      return
    }

    setIsLoading(true)
    try {
      const me = await fetchCurrentUser(currentToken)
      setStoredSession(currentToken, me)
      setToken(currentToken)
      setUser(me)
    } catch {
      logout()
    } finally {
      setIsLoading(false)
    }
  }, [logout])

  const login = useCallback(
    async (cin: string, password: string) => {
      setIsLoading(true)
      try {
        const response = await axiosClient.post<LoginResponse>('/auth/login', {
          cin,
          password,
        })
        const nextToken = response.data.access_token
        if (!nextToken) {
          throw new Error('Token absent dans la reponse login.')
        }

        const me =
          parseAuthUser(response.data.user) ?? (await fetchCurrentUser(nextToken))
        setStoredSession(nextToken, me)
        setToken(nextToken)
        setUser(me)
      } catch (error) {
        logout()
        if (isApiError(error)) {
          throw new Error(error.message, { cause: error })
        }
        throw error
      } finally {
        setIsLoading(false)
      }
    },
    [logout],
  )

  const registerDoctor = useCallback(
    async (payload: RegisterDoctorPayload): Promise<RegisterDoctorResult> => {
      setIsLoading(true)
      try {
        const response = await axiosClient.post<unknown>(
          '/auth/register-doctor',
          payload,
        )

        if (
          isRecord(response.data) &&
          typeof response.data.access_token === 'string' &&
          response.data.access_token.trim().length > 0
        ) {
          const nextToken = response.data.access_token
          const me =
            parseAuthUser(response.data.user) ?? (await fetchCurrentUser(nextToken))
          setStoredSession(nextToken, me)
          setToken(nextToken)
          setUser(me)
          return { loggedIn: true }
        }

        return { loggedIn: false }
      } catch (error) {
        if (isApiError(error)) {
          throw new Error(error.message, { cause: error })
        }
        throw error
      } finally {
        setIsLoading(false)
      }
    },
    [],
  )

  useEffect(() => {
    const timeoutId = window.setTimeout(() => {
      void restoreSession()
    }, 0)

    return () => {
      window.clearTimeout(timeoutId)
    }
  }, [restoreSession])

  useEffect(() => {
    const handleUnauthorized = () => {
      logout()
    }

    window.addEventListener(AUTH_UNAUTHORIZED_EVENT, handleUnauthorized)
    return () => {
      window.removeEventListener(AUTH_UNAUTHORIZED_EVENT, handleUnauthorized)
    }
  }, [logout])

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      token,
      isLoading,
      isAuthenticated: Boolean(token && user),
      login,
      registerDoctor,
      logout,
      restoreSession,
    }),
    [isLoading, login, logout, registerDoctor, restoreSession, token, user],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
