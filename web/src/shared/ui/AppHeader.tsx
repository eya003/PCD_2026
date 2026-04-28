import type { ReactNode } from 'react'

interface AppHeaderProps {
  title: string
  subtitle: string
  actions?: ReactNode
}

export function AppHeader({ title, subtitle, actions }: AppHeaderProps) {
  return (
    <header className="app-header">
      <div className="app-header-main">
        <h2>{title}</h2>
        <p>{subtitle}</p>
      </div>
      {actions && <div className="app-header-actions">{actions}</div>}
    </header>
  )
}
