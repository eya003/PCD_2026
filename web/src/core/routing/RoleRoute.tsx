import { Navigate, Outlet } from 'react-router-dom'

import type { UserRole } from '../auth/types'
import { useAuth } from '../auth/useAuth'

interface RoleRouteProps {
  allowedRoles: UserRole[]
}

export function RoleRoute({ allowedRoles }: RoleRouteProps) {
  const { isAuthenticated, isLoading, user } = useAuth()

  if (isLoading) {
    return (
      <main className="page-center">
        <div className="card loading-card">Verification des droits...</div>
      </main>
    )
  }

  if (!isAuthenticated || !user) {
    return <Navigate replace to="/login" />
  }

  if (!allowedRoles.includes(user.role)) {
    return <Navigate replace to="/dashboard" />
  }

  return <Outlet />
}
