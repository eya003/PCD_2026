export type UserRole = 'doctor' | 'family'

export interface AuthUser {
  id: number
  first_name: string
  last_name: string
  cin: string
  email: string
  role: UserRole
}

export interface LoginResponse {
  access_token: string
  token_type: string
  role: UserRole
  user_id: number
  user?: AuthUser
}

export interface RegisterDoctorPayload {
  first_name: string
  last_name: string
  cin: string
  email: string
  password: string
}

export interface RegisterDoctorResult {
  loggedIn: boolean
}
