import { useMemo } from 'react'

import { useAuth } from '../../../core/auth/useAuth'
import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { EmptyState } from '../../../shared/ui/EmptyState'
import { SectionCard } from '../../../shared/ui/SectionCard'

export function DoctorProfilePage() {
  const { user } = useAuth()

  const fullName = useMemo(() => {
    if (!user) {
      return ''
    }
    return `${user.first_name} ${user.last_name}`.trim()
  }, [user])

  return (
    <DoctorShellLayout title="Profil">
      <AppHeader
        subtitle="Informations du compte medecin connecte."
        title="Profil"
      />

      <SectionCard title="Compte">
        {!user && (
          <EmptyState
            iconLabel="INFO"
            message="Session introuvable."
            title="Utilisateur non connecte"
          />
        )}

        {user && (
          <div className="record-list">
            <article className="record-card">
              <p className="record-subtext">Nom complet</p>
              <p className="record-text">{fullName}</p>
            </article>
            <article className="record-card">
              <p className="record-subtext">CIN</p>
              <p className="record-text">{user.cin}</p>
            </article>
            <article className="record-card">
              <p className="record-subtext">Email</p>
              <p className="record-text">{user.email}</p>
            </article>
            <article className="record-card">
              <p className="record-subtext">Role</p>
              <p className="record-text">medecin</p>
            </article>
          </div>
        )}
      </SectionCard>
    </DoctorShellLayout>
  )
}
