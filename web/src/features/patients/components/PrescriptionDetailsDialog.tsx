import type { PrescriptionDetail } from '../types'

interface PrescriptionDetailsDialogProps {
  isOpen: boolean
  isPrinting: boolean
  detail: PrescriptionDetail | null
  patientName: string
  patientCode: string
  patientCin: string
  patientAgeLabel: string
  prescriberLabel: string
  onClose: () => void
  onPrint: () => void
}

function formatDate(value: string): string {
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return value
  }
  return parsed.toLocaleDateString('fr-FR')
}

export function PrescriptionDetailsDialog({
  isOpen,
  isPrinting,
  detail,
  patientName,
  patientCode,
  patientCin,
  patientAgeLabel,
  prescriberLabel,
  onClose,
  onPrint,
}: PrescriptionDetailsDialogProps) {
  if (!isOpen || !detail) {
    return null
  }

  const prescription = detail.prescription

  return (
    <div aria-modal className="dialog-overlay" role="dialog">
      <div className="dialog-card prescription-details-dialog">
        <header className="dialog-header">
          <h4>Ordonnance du {formatDate(prescription.prescription_date)}</h4>
          <p>Reference #{prescription.id}</p>
        </header>

        <div className="record-list">
          <article className="record-card">
            <div className="record-head">
              <strong>Informations patient</strong>
            </div>
            <p className="record-subtext">
              {patientName} - {patientAgeLabel}
            </p>
            <p className="record-subtext">
              Code: {patientCode} - CIN: {patientCin}
            </p>
          </article>

          <article className="record-card">
            <div className="record-head">
              <strong>Informations ordonnance</strong>
            </div>
            <p className="record-subtext">Prescripteur: {prescriberLabel}</p>
            {prescription.notes?.trim() && (
              <p className="record-subtext">Notes: {prescription.notes.trim()}</p>
            )}
          </article>
        </div>

        <div className="prescription-details-list">
          {detail.medications.length === 0 && (
            <p className="state-text">Aucun medicament lie a cette ordonnance.</p>
          )}

          {detail.medications.map((medication) => (
            <article className="record-card" key={medication.id}>
              <div className="record-head">
                <strong>{medication.name}</strong>
              </div>
              <p className="record-subtext">Dosage: {medication.dosage ?? 'Non precise'}</p>
              <p className="record-subtext">Forme: {medication.form ?? 'Non precisee'}</p>
              <p className="record-subtext">
                Quantite: {medication.quantity ?? 'Non precisee'}
              </p>
              <p className="record-subtext">
                Frequence: {medication.frequency ?? 'Non precisee'}
              </p>
              <p className="record-subtext">Periode: {medication.period ?? 'Non precisee'}</p>
              <p className="record-subtext">
                Dates: {medication.start_date ?? 'Non precisee'}
                {' -> '}
                {medication.end_date ?? 'Non precisee'}
              </p>
              <p className="record-subtext">
                Instructions: {medication.instructions ?? 'Aucune instruction'}
              </p>
            </article>
          ))}
        </div>

        <div className="dialog-actions">
          <button className="btn btn-outline" onClick={onClose} type="button">
            Fermer
          </button>
          <button
            className="btn btn-primary"
            disabled={isPrinting}
            onClick={onPrint}
            type="button"
          >
            {isPrinting ? 'Impression...' : 'Imprimer'}
          </button>
        </div>
      </div>
    </div>
  )
}
