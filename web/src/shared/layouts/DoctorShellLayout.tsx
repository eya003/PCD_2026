import { type ReactNode, useEffect, useMemo, useState } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'

import { useAuth } from '../../core/auth/useAuth'
import type { UserRole } from '../../core/auth/types'

interface DoctorShellLayoutProps {
  title: string
  children: ReactNode
}

interface NavItem {
  key: string
  label: string
  to: string
}

const doctorDrawerNavItems: NavItem[] = [
  { key: 'dashboard', label: 'Dashboard', to: '/dashboard' },
  { key: 'patients', label: 'Patients', to: '/patients' },
  { key: 'ai', label: 'Module IA', to: '/ai' },
  { key: 'about-app', label: 'À propos de l’application', to: '/about-app' },
  { key: 'about-alzheimer', label: 'À propos d’Alzheimer', to: '/about-alzheimer' },
  { key: 'profile', label: 'Profil', to: '/profile' },
]

const doctorBottomNavItems: NavItem[] = [
  { key: 'dashboard', label: 'Dashboard', to: '/dashboard' },
  { key: 'patients', label: 'Patients', to: '/patients' },
  { key: 'ai', label: 'Module IA', to: '/ai' },
  { key: 'profile', label: 'Profil', to: '/profile' },
]

const familyNavItems: NavItem[] = [
  { key: 'dashboard', label: 'Dashboard', to: '/dashboard' },
  { key: 'patients', label: 'Patients', to: '/patients' },
  { key: 'alerts', label: 'Alertes', to: '/alerts' },
  { key: 'location', label: 'Localisation', to: '/location' },
]

function getInitial(firstName: string, email: string): string {
  const normalizedFirstName = firstName.trim()
  if (normalizedFirstName.length > 0) {
    return normalizedFirstName[0].toUpperCase()
  }

  const normalizedEmail = email.trim()
  if (normalizedEmail.length > 0) {
    return normalizedEmail[0].toUpperCase()
  }

  return 'D'
}

export function DoctorShellLayout({
  title,
  children,
}: DoctorShellLayoutProps) {
  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const [isMobileDrawerOpen, setIsMobileDrawerOpen] = useState(false)
  const [isDesktopDrawerCollapsed, setIsDesktopDrawerCollapsed] = useState(false)
  const [isMobileViewport, setIsMobileViewport] = useState(() => {
    if (typeof window === 'undefined') {
      return false
    }
    return window.matchMedia('(max-width: 960px)').matches
  })

  const initial = useMemo(() => {
    return getInitial(user?.first_name ?? '', user?.email ?? '')
  }, [user?.email, user?.first_name])

  const userLabel = useMemo(() => {
    const fullName = `${user?.first_name ?? ''} ${user?.last_name ?? ''}`.trim()
    if (fullName.length > 0) {
      return fullName
    }
    return user?.email ?? 'Utilisateur'
  }, [user?.email, user?.first_name, user?.last_name])

  useEffect(() => {
    if (typeof window === 'undefined') {
      return
    }

    const mediaQuery = window.matchMedia('(max-width: 960px)')
    const handleChange = (event: MediaQueryListEvent) => {
      const matches = event.matches
      setIsMobileViewport(matches)
      if (!matches) {
        setIsMobileDrawerOpen(false)
      } else {
        setIsDesktopDrawerCollapsed(false)
      }
    }

    mediaQuery.addEventListener('change', handleChange)
    return () => {
      mediaQuery.removeEventListener('change', handleChange)
    }
  }, [])

  function closeDrawer() {
    setIsMobileDrawerOpen(false)
  }

  function toggleDrawer() {
    if (isMobileViewport) {
      setIsMobileDrawerOpen((current) => !current)
      return
    }
    setIsDesktopDrawerCollapsed((current) => !current)
  }

  const shellClassName = isDesktopDrawerCollapsed
    ? 'doctor-shell is-drawer-collapsed'
    : 'doctor-shell'
  const drawerClassName = isMobileDrawerOpen
    ? 'doctor-drawer is-open'
    : 'doctor-drawer'
  const role: UserRole = user?.role === 'family' ? 'family' : 'doctor'
  const drawerNavItems = role === 'family' ? familyNavItems : doctorDrawerNavItems
  const bottomNavItems = role === 'family' ? familyNavItems : doctorBottomNavItems
  const navLabel =
    role === 'family' ? 'Navigation famille' : 'Navigation medecin'
  const menuButtonLabel = isMobileViewport
    ? (isMobileDrawerOpen ? 'Fermer menu' : 'Ouvrir menu')
    : (isDesktopDrawerCollapsed ? 'Afficher menu' : 'Masquer menu')
  const bottomNavStyle = useMemo(() => {
    return {
      gridTemplateColumns: `repeat(${bottomNavItems.length}, 1fr)`,
    }
  }, [bottomNavItems.length])

  return (
    <div className={shellClassName}>
      <aside className={drawerClassName}>
        <div className="doctor-brand">
          <span className="doctor-brand-avatar">A</span>
          <div>
            <strong>AlzCare</strong>
            <p>{user?.email ?? ''}</p>
          </div>
        </div>

        <nav className="doctor-nav" aria-label={navLabel}>
          {drawerNavItems.map((item) => {
            return (
              <NavLink
                className={({ isActive }) => {
                  return isActive
                    ? 'doctor-nav-item is-active'
                    : 'doctor-nav-item'
                }}
                key={item.key}
                onClick={() => {
                  if (isMobileViewport) {
                    closeDrawer()
                  }
                }}
                to={item.to}
              >
                {item.label}
              </NavLink>
            )
          })}
        </nav>

        <button
          className="btn btn-outline doctor-logout-button"
          onClick={logout}
          type="button"
        >
          Deconnexion
        </button>
      </aside>

      {isMobileDrawerOpen && (
        <button
          aria-label="Fermer le menu"
          className="doctor-drawer-backdrop"
          onClick={closeDrawer}
          type="button"
        />
      )}

      <div className="doctor-main">
        <header className="doctor-topbar">
          <button
            aria-label={menuButtonLabel}
            className="doctor-menu-button"
            onClick={toggleDrawer}
            type="button"
          >
            {menuButtonLabel}
          </button>

          <h1>{title}</h1>

          <div className="doctor-topbar-actions">
            <span className="doctor-user-chip">{userLabel}</span>
            <button
              className="avatar-button"
              onClick={() => navigate('/profile')}
              title="Aller au profil"
              type="button"
            >
              {initial}
            </button>
          </div>
        </header>

        <main className="doctor-content">{children}</main>
      </div>

      <nav
        aria-label={navLabel}
        className="doctor-bottom-nav"
        style={bottomNavStyle}
      >
        {bottomNavItems.map((item) => {
          return (
            <NavLink
              className={({ isActive }) => {
                return isActive
                  ? 'doctor-bottom-item is-active'
                  : 'doctor-bottom-item'
              }}
              key={item.key}
              onClick={() => {
                if (isMobileViewport) {
                  closeDrawer()
                }
              }}
              to={item.to}
            >
              {item.label}
            </NavLink>
          )
        })}
      </nav>
    </div>
  )
}
