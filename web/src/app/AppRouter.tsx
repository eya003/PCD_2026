import { Navigate, Route, Routes } from 'react-router-dom'

import { useAuth } from '../core/auth/useAuth'
import { RoleRoute } from '../core/routing/RoleRoute'
import { ProtectedRoute } from '../core/routing/ProtectedRoute'
import { LoginPage } from '../features/auth/pages/LoginPage'
import { DoctorAiPage } from '../features/doctor/pages/DoctorAiPage'
import { DoctorAboutAlzheimerPage } from '../features/doctor/pages/DoctorAboutAlzheimerPage'
import { DoctorAboutAppDetailPage } from '../features/doctor/pages/DoctorAboutAppDetailPage'
import { DoctorAboutAppPage } from '../features/doctor/pages/DoctorAboutAppPage'
import { DoctorDashboardPage } from '../features/doctor/pages/DoctorDashboardPage'
import { DoctorPatientsPage } from '../features/doctor/pages/DoctorPatientsPage'
import { DoctorProfilePage } from '../features/doctor/pages/DoctorProfilePage'
import { FamilyAlertsPage } from '../features/family/pages/FamilyAlertsPage'
import { FamilyDashboardPage } from '../features/family/pages/FamilyDashboardPage'
import { FamilyLocationPage } from '../features/family/pages/FamilyLocationPage'
import { FamilyPatientsPage } from '../features/family/pages/FamilyPatientsPage'
import { CreatePatientPage } from '../features/patients/pages/CreatePatientPage'
import { PatientDetailsPage } from '../features/patients/pages/PatientDetailsPage'

function RedirectBySession() {
  const { isAuthenticated, user } = useAuth()
  if (!isAuthenticated || !user) {
    return <Navigate replace to="/login" />
  }
  return <Navigate replace to="/dashboard" />
}

function LoginRoute() {
  const { isAuthenticated, user } = useAuth()
  if (isAuthenticated && user) {
    return <Navigate replace to="/dashboard" />
  }
  return <LoginPage />
}

function DashboardRoute() {
  const { user } = useAuth()
  if (!user) {
    return <Navigate replace to="/login" />
  }

  if (user.role === 'family') {
    return <FamilyDashboardPage />
  }
  return <DoctorDashboardPage />
}

function PatientsRoute() {
  const { user } = useAuth()
  if (!user) {
    return <Navigate replace to="/login" />
  }

  if (user.role === 'family') {
    return <FamilyPatientsPage />
  }
  return <DoctorPatientsPage />
}

export function AppRouter() {
  return (
    <Routes>
      <Route path="/" element={<RedirectBySession />} />
      <Route path="/login" element={<LoginRoute />} />

      <Route element={<ProtectedRoute />}>
        <Route path="/dashboard" element={<DashboardRoute />} />
        <Route path="/patients" element={<PatientsRoute />} />
        <Route path="/patients/:patientId" element={<PatientDetailsPage />} />

        <Route element={<RoleRoute allowedRoles={['doctor']} />}>
          <Route path="/patients/new" element={<CreatePatientPage />} />
          <Route path="/ai" element={<DoctorAiPage />} />
          <Route path="/about-app" element={<DoctorAboutAppPage />} />
          <Route
            path="/about-app/detail/:section/:index"
            element={<DoctorAboutAppDetailPage />}
          />
          <Route path="/about-alzheimer" element={<DoctorAboutAlzheimerPage />} />
          <Route path="/profile" element={<DoctorProfilePage />} />
        </Route>

        <Route element={<RoleRoute allowedRoles={['family']} />}>
          <Route path="/alerts" element={<FamilyAlertsPage />} />
          <Route path="/location" element={<FamilyLocationPage />} />
        </Route>
      </Route>

      <Route path="*" element={<RedirectBySession />} />
    </Routes>
  )
}
