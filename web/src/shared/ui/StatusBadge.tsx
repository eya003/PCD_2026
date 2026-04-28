export type StatusBadgeTone =
  | 'neutral'
  | 'primary'
  | 'success'
  | 'warning'
  | 'danger'

interface StatusBadgeProps {
  label: string
  tone?: StatusBadgeTone
}

export function StatusBadge({
  label,
  tone = 'neutral',
}: StatusBadgeProps) {
  return (
    <span className={`status-badge status-badge-${tone}`}>{label}</span>
  )
}
