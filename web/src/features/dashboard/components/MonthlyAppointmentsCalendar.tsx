import { useEffect, useMemo, useState } from 'react'

import type { AppointmentStatus } from '../../patients/types'

export interface DashboardAppointment {
  id: number
  patientId: number
  patientName: string
  appointmentDate: string
  notes: string | null
  status: AppointmentStatus
}

interface MonthlyAppointmentsCalendarProps {
  appointments: DashboardAppointment[]
  onAddAppointment?: () => void
  onSelectDate?: (date: string) => void
  onAddAppointmentOnDate?: (date: string) => void
  selectedDate?: string | null
}

const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']

function toDateKey(date: Date): string {
  const year = date.getFullYear().toString().padStart(4, '0')
  const month = `${date.getMonth() + 1}`.padStart(2, '0')
  const day = `${date.getDate()}`.padStart(2, '0')
  return `${year}-${month}-${day}`
}

function toDateKeyFromIso(value: string): string | null {
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return null
  }
  return toDateKey(parsed)
}

function getMonthLabel(monthDate: Date): string {
  return monthDate.toLocaleDateString('fr-FR', {
    month: 'long',
    year: 'numeric',
  })
}

function getStatusToneClass(
  status: AppointmentStatus,
): 'primary' | 'success' | 'warning' | 'danger' {
  if (status === 'done') return 'success'
  if (status === 'cancelled') return 'warning'
  if (status === 'missed') return 'danger'
  return 'primary'
}

function buildCalendarDays(visibleMonth: Date): Date[] {
  const firstDay = new Date(
    visibleMonth.getFullYear(),
    visibleMonth.getMonth(),
    1,
  )
  const firstDayOffset = (firstDay.getDay() + 6) % 7
  const startDate = new Date(firstDay)
  startDate.setDate(firstDay.getDate() - firstDayOffset)

  const lastDay = new Date(
    visibleMonth.getFullYear(),
    visibleMonth.getMonth() + 1,
    0,
  )
  const lastDayOffset = 6 - ((lastDay.getDay() + 6) % 7)
  const endDate = new Date(lastDay)
  endDate.setDate(lastDay.getDate() + lastDayOffset)

  const days: Date[] = []
  const cursor = new Date(startDate)
  while (cursor <= endDate) {
    days.push(new Date(cursor))
    cursor.setDate(cursor.getDate() + 1)
  }

  return days
}

export function MonthlyAppointmentsCalendar({
  appointments,
  onAddAppointment,
  onSelectDate,
  onAddAppointmentOnDate,
  selectedDate,
}: MonthlyAppointmentsCalendarProps) {
  const [visibleMonth, setVisibleMonth] = useState(() => {
    const today = new Date()
    return new Date(today.getFullYear(), today.getMonth(), 1)
  })
  const [contextMenu, setContextMenu] = useState<{
    date: string
    x: number
    y: number
  } | null>(null)

  const calendarDays = useMemo(() => {
    return buildCalendarDays(visibleMonth)
  }, [visibleMonth])

  const appointmentsByDay = useMemo(() => {
    const dayMap = new Map<string, DashboardAppointment[]>()

    for (const appointment of appointments) {
      const key = toDateKeyFromIso(appointment.appointmentDate)
      if (!key) {
        continue
      }
      const bucket = dayMap.get(key)
      if (bucket) {
        bucket.push(appointment)
      } else {
        dayMap.set(key, [appointment])
      }
    }

    for (const dayAppointments of dayMap.values()) {
      dayAppointments.sort((left, right) => {
        const leftTime = new Date(left.appointmentDate).getTime()
        const rightTime = new Date(right.appointmentDate).getTime()
        return leftTime - rightTime
      })
    }

    return dayMap
  }, [appointments])

  const currentMonthLabel = useMemo(() => {
    return getMonthLabel(visibleMonth)
  }, [visibleMonth])

  const today = useMemo(() => {
    const now = new Date()
    return toDateKey(now)
  }, [])

  useEffect(() => {
    if (!contextMenu) {
      return
    }

    const handleWindowClick = () => {
      setContextMenu(null)
    }
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setContextMenu(null)
      }
    }

    window.addEventListener('click', handleWindowClick)
    window.addEventListener('scroll', handleWindowClick, true)
    window.addEventListener('keydown', handleEscape)
    return () => {
      window.removeEventListener('click', handleWindowClick)
      window.removeEventListener('scroll', handleWindowClick, true)
      window.removeEventListener('keydown', handleEscape)
    }
  }, [contextMenu])

  return (
    <div className="dashboard-calendar">
      <div className="dashboard-calendar-header">
        <button
          className="btn btn-outline dashboard-calendar-nav"
          onClick={() => {
            setVisibleMonth((current) => {
              return new Date(current.getFullYear(), current.getMonth() - 1, 1)
            })
          }}
          type="button"
        >
          Mois precedent
        </button>

        <strong className="dashboard-calendar-month">{currentMonthLabel}</strong>

        <div className="dashboard-calendar-header-actions">
          {onAddAppointment && (
            <button
              className="btn btn-primary dashboard-calendar-nav"
              onClick={onAddAppointment}
              type="button"
            >
              Ajouter rendez-vous
            </button>
          )}
          <button
            className="btn btn-outline dashboard-calendar-nav"
            onClick={() => {
              const now = new Date()
              setVisibleMonth(new Date(now.getFullYear(), now.getMonth(), 1))
            }}
            type="button"
          >
            Aujourd hui
          </button>
          <button
            className="btn btn-outline dashboard-calendar-nav"
            onClick={() => {
              setVisibleMonth((current) => {
                return new Date(current.getFullYear(), current.getMonth() + 1, 1)
              })
            }}
            type="button"
          >
            Mois suivant
          </button>
        </div>
      </div>

      <div className="dashboard-calendar-weekdays">
        {weekDays.map((label) => (
          <span className="dashboard-calendar-weekday" key={label}>
            {label}
          </span>
        ))}
      </div>

      <div className="dashboard-calendar-grid">
        {calendarDays.map((day) => {
          const dayKey = toDateKey(day)
          const dayAppointments = appointmentsByDay.get(dayKey) ?? []
          const isCurrentMonth = day.getMonth() === visibleMonth.getMonth()
          const isToday = dayKey === today
          const dayClassName = [
            'dashboard-calendar-day',
            isCurrentMonth ? '' : 'is-outside-month',
            isToday ? 'is-today' : '',
            selectedDate === dayKey ? 'is-selected' : '',
            onSelectDate ? 'is-clickable' : '',
          ]
            .filter(Boolean)
            .join(' ')

          return (
            <article
              className={dayClassName}
              key={dayKey}
              onClick={() => {
                setContextMenu(null)
                onSelectDate?.(dayKey)
              }}
              onContextMenu={(event) => {
                event.preventDefault()
                setContextMenu({
                  date: dayKey,
                  x: event.clientX,
                  y: event.clientY,
                })
              }}
              role={onSelectDate ? 'button' : undefined}
              tabIndex={onSelectDate ? 0 : undefined}
              onKeyDown={(event) => {
                if (!onSelectDate) {
                  return
                }
                if (event.key === 'Enter' || event.key === ' ') {
                  event.preventDefault()
                  onSelectDate(dayKey)
                }
              }}
            >
              <span className="dashboard-calendar-day-number">{day.getDate()}</span>

              <div className="dashboard-calendar-day-appointments">
                {dayAppointments.slice(0, 2).map((appointment) => {
                  const toneClass = getStatusToneClass(appointment.status)
                  return (
                    <span
                      aria-label={`${appointment.patientName} ${appointment.appointmentDate}`}
                      className={`dashboard-calendar-dot tone-${toneClass}`}
                      key={appointment.id}
                      title={appointment.patientName}
                    />
                  )
                })}

                {dayAppointments.length > 2 && (
                  <span className="dashboard-calendar-more">
                    +{dayAppointments.length - 2}
                  </span>
                )}
              </div>
            </article>
          )
        })}
      </div>

      {contextMenu && (
        <div
          className="dashboard-calendar-context-menu"
          onClick={(event) => {
            event.stopPropagation()
          }}
          onContextMenu={(event) => {
            event.preventDefault()
          }}
          role="menu"
          style={{
            left: contextMenu.x,
            top: contextMenu.y,
          }}
        >
          <button
            className="dashboard-calendar-context-action"
            onClick={() => {
              setContextMenu(null)
              onAddAppointmentOnDate?.(contextMenu.date)
            }}
            type="button"
          >
            Ajouter rendez-vous ce jour
          </button>
        </div>
      )}
    </div>
  )
}
