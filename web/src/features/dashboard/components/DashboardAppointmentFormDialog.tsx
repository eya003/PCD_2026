import { type FormEvent, useMemo, useState } from 'react'

export interface DashboardAppointmentPatientOption {
  id: number
  label: string
}

export interface DashboardAppointmentFormValues {
  patientId: number
  date: string
  time: string
  notes: string
}

interface DashboardAppointmentFormDialogProps {
  isOpen: boolean
  isSubmitting: boolean
  initialDate: string
  patients: DashboardAppointmentPatientOption[]
  onClose: () => void
  onSubmit: (values: DashboardAppointmentFormValues) => Promise<void>
}

export function DashboardAppointmentFormDialog({
  isOpen,
  isSubmitting,
  initialDate,
  patients,
  onClose,
  onSubmit,
}: DashboardAppointmentFormDialogProps) {
  const defaultPatientId = useMemo(() => {
    return patients.length > 0 ? patients[0].id : 0
  }, [patients])

  const [patientId, setPatientId] = useState<number>(defaultPatientId)
  const [dateValue, setDateValue] = useState(initialDate)
  const [timeValue, setTimeValue] = useState('')
  const [notes, setNotes] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

  if (!isOpen) {
    return null
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFormError(null)

    if (!patients.length) {
      setFormError('Aucun patient disponible.')
      return
    }

    if (!patientId) {
      setFormError('Patient obligatoire.')
      return
    }

    if (!dateValue || !timeValue) {
      setFormError('Date et heure obligatoires.')
      return
    }

    await onSubmit({
      patientId,
      date: dateValue,
      time: timeValue,
      notes: notes.trim(),
    })
  }

  return (
    <div aria-modal className="dialog-overlay" role="dialog">
      <div className="dialog-card">
        <header className="dialog-header">
          <h4>Ajouter rendez-vous</h4>
          <p>Creation rapide depuis le dashboard</p>
        </header>

        {formError && (
          <div className="feedback-banner is-error" role="alert">
            {formError}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="dialog-grid">
            <label className="field-block full">
              <span>Patient</span>
              <select
                className="input-control"
                disabled={isSubmitting || patients.length === 0}
                onChange={(event) => setPatientId(Number.parseInt(event.target.value, 10))}
                value={patientId}
              >
                {patients.map((patient) => (
                  <option key={patient.id} value={patient.id}>
                    {patient.label}
                  </option>
                ))}
              </select>
            </label>

            <label className="field-block">
              <span>Date</span>
              <input
                className="input-control"
                disabled={isSubmitting}
                onChange={(event) => setDateValue(event.target.value)}
                type="date"
                value={dateValue}
              />
            </label>

            <label className="field-block">
              <span>Heure</span>
              <input
                className="input-control"
                disabled={isSubmitting}
                onChange={(event) => setTimeValue(event.target.value)}
                type="time"
                value={timeValue}
              />
            </label>

            <label className="field-block full">
              <span>Notes (optionnel)</span>
              <textarea
                className="input-control"
                disabled={isSubmitting}
                onChange={(event) => setNotes(event.target.value)}
                rows={3}
                value={notes}
              />
            </label>
          </div>

          <div className="dialog-actions">
            <button
              className="btn btn-outline"
              disabled={isSubmitting}
              onClick={onClose}
              type="button"
            >
              Annuler
            </button>
            <button
              className="btn btn-primary"
              disabled={isSubmitting || patients.length === 0}
              type="submit"
            >
              {isSubmitting ? 'Creation...' : 'Ajouter rendez-vous'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
