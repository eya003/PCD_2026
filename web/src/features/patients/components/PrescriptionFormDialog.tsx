import { type FormEvent, useMemo, useState } from 'react'

import type { MedicationFormData } from '../types'

interface PrescriptionFormDialogProps {
  isOpen: boolean
  isSubmitting: boolean
  patientName: string
  onClose: () => void
  onSubmit: (values: PrescriptionFormValues) => Promise<void>
}

interface MedicationDraft extends MedicationFormData {
  draftId: string
}

export interface PrescriptionFormValues {
  prescriptionDate: string
  notes: string
  medications: MedicationFormData[]
}

function createDraftId(): string {
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`
}

function createEmptyMedicationDraft(): MedicationDraft {
  return {
    draftId: createDraftId(),
    name: '',
    dosage: '',
    form: '',
    quantity: '',
    frequency: '',
    period: '',
    startDate: '',
    endDate: '',
    instructions: '',
  }
}

function toDateInput(date: Date): string {
  const year = date.getFullYear().toString().padStart(4, '0')
  const month = `${date.getMonth() + 1}`.padStart(2, '0')
  const day = `${date.getDate()}`.padStart(2, '0')
  return `${year}-${month}-${day}`
}

function getFormValidationError(values: PrescriptionFormValues): string | null {
  if (!values.prescriptionDate) {
    return 'Date de prescription obligatoire.'
  }

  if (values.medications.length === 0) {
    return 'Ajoutez au moins un medicament.'
  }

  for (let index = 0; index < values.medications.length; index += 1) {
    const medication = values.medications[index]
    const position = index + 1

    if (!medication.name.trim()) return `Nom medicament obligatoire (#${position}).`
    if (!medication.dosage.trim()) return `Dosage obligatoire (#${position}).`
    if (!medication.quantity.trim()) return `Quantite obligatoire (#${position}).`
    if (!medication.frequency.trim()) return `Frequence obligatoire (#${position}).`
    if (!medication.period.trim()) return `Periode / duree obligatoire (#${position}).`
    if (!medication.startDate.trim()) return `Date debut obligatoire (#${position}).`
    if (!medication.instructions.trim()) {
      return `Instructions obligatoires (#${position}).`
    }

    if (medication.endDate.trim() && medication.endDate < medication.startDate) {
      return `Date fin doit etre >= date debut (#${position}).`
    }
  }

  return null
}

export function PrescriptionFormDialog({
  isOpen,
  isSubmitting,
  patientName,
  onClose,
  onSubmit,
}: PrescriptionFormDialogProps) {
  const initialDate = useMemo(() => toDateInput(new Date()), [])
  const [prescriptionDate, setPrescriptionDate] = useState(initialDate)
  const [notes, setNotes] = useState('')
  const [medications, setMedications] = useState<MedicationDraft[]>([
    createEmptyMedicationDraft(),
  ])
  const [formError, setFormError] = useState<string | null>(null)

  if (!isOpen) {
    return null
  }

  function handleMedicationChange(
    draftId: string,
    field: keyof MedicationFormData,
    value: string,
  ) {
    setMedications((current) => {
      return current.map((item) => {
        if (item.draftId !== draftId) {
          return item
        }
        if (field === 'startDate') {
          const nextEndDate =
            item.endDate && item.endDate < value ? '' : item.endDate
          return { ...item, startDate: value, endDate: nextEndDate }
        }
        return { ...item, [field]: value }
      })
    })
  }

  function addMedication() {
    setMedications((current) => [...current, createEmptyMedicationDraft()])
  }

  function removeMedication(draftId: string) {
    setMedications((current) => {
      if (current.length <= 1) {
        return current
      }
      return current.filter((item) => item.draftId !== draftId)
    })
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFormError(null)

    const values: PrescriptionFormValues = {
      prescriptionDate,
      notes,
      medications: medications.map((item) => ({
        name: item.name,
        dosage: item.dosage,
        form: item.form,
        quantity: item.quantity,
        frequency: item.frequency,
        period: item.period,
        startDate: item.startDate,
        endDate: item.endDate,
        instructions: item.instructions,
      })),
    }

    const validationError = getFormValidationError(values)
    if (validationError) {
      setFormError(validationError)
      return
    }

    await onSubmit(values)
  }

  return (
    <div aria-modal className="dialog-overlay" role="dialog">
      <div className="dialog-card prescription-dialog">
        <header className="dialog-header">
          <h4>Nouvelle ordonnance</h4>
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
              <span>
                Date de prescription
                <span className="required-star">*</span>
              </span>
              <input
                className="input-control"
                onChange={(event) => setPrescriptionDate(event.target.value)}
                type="date"
                value={prescriptionDate}
              />
            </label>

            <label className="field-block full">
              <span>Notes ordonnance</span>
              <textarea
                className="input-control"
                onChange={(event) => setNotes(event.target.value)}
                rows={3}
                value={notes}
              />
            </label>
          </div>

          <div className="prescription-medication-list">
            {medications.map((medication, index) => (
              <article className="prescription-medication-card" key={medication.draftId}>
                <div className="prescription-medication-head">
                  <strong>Medicament {index + 1}</strong>
                  <button
                    className="appointment-action-button danger"
                    disabled={isSubmitting || medications.length <= 1}
                    onClick={() => removeMedication(medication.draftId)}
                    type="button"
                  >
                    Supprimer
                  </button>
                </div>

                <div className="dialog-grid">
                  <label className="field-block">
                    <span>
                      Nom medicament
                      <span className="required-star">*</span>
                    </span>
                    <input
                      className="input-control"
                      onChange={(event) => {
                        handleMedicationChange(
                          medication.draftId,
                          'name',
                          event.target.value,
                        )
                      }}
                      type="text"
                      value={medication.name}
                    />
                  </label>

                  <label className="field-block">
                    <span>
                      Dosage
                      <span className="required-star">*</span>
                    </span>
                    <input
                      className="input-control"
                      onChange={(event) => {
                        handleMedicationChange(
                          medication.draftId,
                          'dosage',
                          event.target.value,
                        )
                      }}
                      type="text"
                      value={medication.dosage}
                    />
                  </label>

                  <label className="field-block">
                    <span>Forme</span>
                    <input
                      className="input-control"
                      onChange={(event) => {
                        handleMedicationChange(
                          medication.draftId,
                          'form',
                          event.target.value,
                        )
                      }}
                      type="text"
                      value={medication.form}
                    />
                  </label>

                  <label className="field-block">
                    <span>
                      Quantite
                      <span className="required-star">*</span>
                    </span>
                    <input
                      className="input-control"
                      onChange={(event) => {
                        handleMedicationChange(
                          medication.draftId,
                          'quantity',
                          event.target.value,
                        )
                      }}
                      type="text"
                      value={medication.quantity}
                    />
                  </label>

                  <label className="field-block">
                    <span>
                      Frequence
                      <span className="required-star">*</span>
                    </span>
                    <input
                      className="input-control"
                      onChange={(event) => {
                        handleMedicationChange(
                          medication.draftId,
                          'frequency',
                          event.target.value,
                        )
                      }}
                      type="text"
                      value={medication.frequency}
                    />
                  </label>

                  <label className="field-block">
                    <span>
                      Periode / duree
                      <span className="required-star">*</span>
                    </span>
                    <input
                      className="input-control"
                      onChange={(event) => {
                        handleMedicationChange(
                          medication.draftId,
                          'period',
                          event.target.value,
                        )
                      }}
                      type="text"
                      value={medication.period}
                    />
                  </label>

                  <label className="field-block">
                    <span>
                      Date debut
                      <span className="required-star">*</span>
                    </span>
                    <input
                      className="input-control"
                      onChange={(event) => {
                        handleMedicationChange(
                          medication.draftId,
                          'startDate',
                          event.target.value,
                        )
                      }}
                      type="date"
                      value={medication.startDate}
                    />
                  </label>

                  <label className="field-block">
                    <span>Date fin (optionnel)</span>
                    <input
                      className="input-control"
                      onChange={(event) => {
                        handleMedicationChange(
                          medication.draftId,
                          'endDate',
                          event.target.value,
                        )
                      }}
                      type="date"
                      value={medication.endDate}
                    />
                  </label>

                  <label className="field-block full">
                    <span>
                      Instructions
                      <span className="required-star">*</span>
                    </span>
                    <textarea
                      className="input-control"
                      onChange={(event) => {
                        handleMedicationChange(
                          medication.draftId,
                          'instructions',
                          event.target.value,
                        )
                      }}
                      rows={3}
                      value={medication.instructions}
                    />
                  </label>
                </div>
              </article>
            ))}
          </div>

          <div className="prescription-form-actions">
            <button
              className="btn btn-outline"
              disabled={isSubmitting}
              onClick={addMedication}
              type="button"
            >
              Ajouter un medicament
            </button>
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
            <button className="btn btn-primary" disabled={isSubmitting} type="submit">
              {isSubmitting ? 'Creation...' : 'Creer ordonnance et medicaments'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
