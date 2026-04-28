import { createContext } from 'react'

import type {
  AuthUser,
  RegisterDoctorPayload,
  RegisterDoctorResult,
} from './types'

export interface AuthContextValue {
  user: AuthUser | null
  token: string | null
  isAuthenticated: boolean
  isLoading: boolean
  login: (cin: string, password: string) => Promise<void>
  registerDoctor: (payload: RegisterDoctorPayload) => Promise<RegisterDoctorResult>
  logout: () => void
  restoreSession: () => Promise<void>
}

export const AuthContext = createContext<AuthContextValue | undefined>(undefined)
