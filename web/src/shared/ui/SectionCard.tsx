import type { ReactNode } from 'react'

interface SectionCardProps {
  title: string
  children: ReactNode
  action?: ReactNode
  className?: string
}

export function SectionCard({
  title,
  children,
  action,
  className,
}: SectionCardProps) {
  const classes = className
    ? `section-card ${className}`
    : 'section-card'

  return (
    <section className={classes}>
      <div className="section-card-header">
        <h3>{title}</h3>
        {action && <div className="section-card-action">{action}</div>}
      </div>
      <div className="section-card-body">{children}</div>
    </section>
  )
}
