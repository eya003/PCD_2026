interface EmptyStateProps {
  title: string
  message: string
  iconLabel?: string
}

export function EmptyState({
  title,
  message,
  iconLabel = 'INFO',
}: EmptyStateProps) {
  return (
    <div className="empty-state" role="status">
      <span aria-hidden className="empty-state-icon">
        {iconLabel}
      </span>
      <h4>{title}</h4>
      <p>{message}</p>
    </div>
  )
}
