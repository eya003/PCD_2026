import { type FormEvent, useState } from 'react'

import type { AllergySeverity } from '../types'

export interface AllergyFormValues {
  allergen: string
  reaction: string
  severity: AllergySeverity
  notes: string
}

interface AllergyFormDialogProps {
  isOpen: boolean
  isSubmitting: boolean
  patientName: string
  onClose: () => void
  onSubmit: (values: AllergyFormValues) => Promise<void>
}

const DEFAULT_SEVERITY: AllergySeverity = 'moderate'

export function AllergyFormDialog({
  isOpen,
  isSubmitting,
  patientName,
  onClose,
  onSubmit,
}: AllergyFormDialogProps) {
  const [allergen, setAllergen] = useState('')
  const [reaction, setReaction] = useState('')
  const [severity, setSeverity] = useState<AllergySeverity>(DEFAULT_SEVERITY)
  const [notes, setNotes] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

  if (!isOpen) {
    return null
  }

  function resetFormState() {
    setFormError(null)
    setAllergen('')
    setReaction('')
    setSeverity(DEFAULT_SEVERITY)
    setNotes('')
  }

  function handleClose() {
    if (isSubmitting) {
      return
    }
    resetFormState()
    onClose()
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFormError(null)

    const allergenValue = allergen.trim()
    const reactionValue = reaction.trim()

    if (!allergenValue) {
      setFormError('Allergene obligatoire.')
      return
    }

    if (!reactionValue) {
      setFormError('Reaction obligatoire.')
      return
    }

    await onSubmit({
      allergen: allergenValue,
      reaction: reactionValue,
      severity,
      notes: notes.trim(),
    })
  }

  return (
    <div aria-modal className="dialog-overlay" role="dialog">
      <div className="dialog-card">
        <header className="dialog-header">
          <h4>Ajouter allergie</h4>
          <p>Pour {patientName}</p>
        </header>

        {formError && (
          <div className="feedback-banner is-error" role="alert">
            {formError}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="dialog-grid">
            <label className="field-block">
              <span>Allergene *</span>
              <input
                autoComplete="off"
                className="input-control"
                disabled={isSubmitting}
                onChange={(event) => setAllergen(event.target.value)}
                placeholder="Ex: Penicilline"
                type="text"
                value={allergen}
              />
            </label>

            <label className="field-block">
              <span>Severite</span>
              <select
                className="input-control"
                disabled={isSubmitting}
                onChange={(event) => {
                  setSeverity(event.target.value as AllergySeverity)
                }}
                value={severity}
              >
                <option value="low">Faible</option>
                <option value="moderate">Moderee</option>
                <option value="high">Elevee</option>
                <option value="critical">Critique</option>
              </select>
            </label>

            <label className="field-block full">
              <span>Reaction *</span>
              <input
                autoComplete="off"
                className="input-control"
                disabled={isSubmitting}
                onChange={(event) => setReaction(event.target.value)}
                placeholder="Ex: Eruption cutanee, gonflement"
                type="text"
                value={reaction}
              />
            </label>

            <label className="field-block full">
              <span>Notes</span>
              <textarea
                className="input-control"
                disabled={isSubmitting}
                onChange={(event) => setNotes(event.target.value)}
                placeholder="Informations complementaires..."
                rows={3}
                value={notes}
              />
            </label>
          </div>

          <div className="dialog-actions">
            <button
              className="btn btn-outline"
              disabled={isSubmitting}
              onClick={handleClose}
              type="button"
            >
              Annuler
            </button>
            <button className="btn btn-primary" disabled={isSubmitting} type="submit">
              {isSubmitting ? 'Ajout...' : 'Ajouter'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
