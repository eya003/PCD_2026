import { useContext } from 'react'

import { AuthContext, type AuthContextValue } from './authContextStore'

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth doit etre utilise a l interieur de AuthProvider.')
  }
  return context
}
