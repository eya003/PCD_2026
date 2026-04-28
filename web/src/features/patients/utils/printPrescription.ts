import type { PrescriptionDetail } from '../types'

interface PrintPrescriptionPayload {
  detail: PrescriptionDetail
  doctorDisplayName: string
  patientFullName: string
  patientCode: string
  patientCin: string
  patientAgeLabel: string
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

function formatDate(value: string): string {
  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return value
  }
  return parsed.toLocaleDateString('fr-FR')
}

function buildPrintHtml({
  detail,
  doctorDisplayName,
  patientFullName,
  patientCode,
  patientCin,
  patientAgeLabel,
}: PrintPrescriptionPayload): string {
  const { prescription, medications } = detail
  const notes = prescription.notes?.trim() ?? ''
  const rows = medications
    .map((medication) => {
      return `
        <tr>
          <td>${escapeHtml(medication.name)}</td>
          <td>${escapeHtml(medication.dosage ?? '-')}</td>
          <td>${escapeHtml(medication.form ?? '-')}</td>
          <td>${escapeHtml(medication.quantity ?? '-')}</td>
          <td>${escapeHtml(medication.frequency ?? '-')}</td>
          <td>${escapeHtml(medication.period ?? '-')}</td>
          <td>${escapeHtml(medication.start_date ?? '-')}</td>
          <td>${escapeHtml(medication.end_date ?? '-')}</td>
          <td>${escapeHtml(medication.instructions ?? '-')}</td>
        </tr>
      `
    })
    .join('')

  return `<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <title>Ordonnance du ${formatDate(prescription.prescription_date)}</title>
  <style>
    body { font-family: "Segoe UI", Arial, sans-serif; color: #0f172a; margin: 24px; }
    h1 { margin: 0 0 8px; font-size: 24px; }
    h2 { margin: 24px 0 8px; font-size: 18px; }
    p { margin: 4px 0; }
    .muted { color: #64748b; }
    table { width: 100%; border-collapse: collapse; margin-top: 12px; }
    th, td { border: 1px solid #dbe2ec; padding: 8px; font-size: 12px; text-align: left; vertical-align: top; }
    th { background: #f8fafc; }
    .meta { display: grid; gap: 4px; }
    @media print { body { margin: 0; } }
  </style>
</head>
<body>
  <h1>Ordonnance du ${escapeHtml(formatDate(prescription.prescription_date))}</h1>
  <div class="meta">
    <p><strong>Reference:</strong> #${prescription.id}</p>
    <p><strong>Prescripteur:</strong> ${escapeHtml(doctorDisplayName)}</p>
  </div>

  <h2>Patient</h2>
  <div class="meta">
    <p><strong>Nom:</strong> ${escapeHtml(patientFullName)}</p>
    <p><strong>Code:</strong> ${escapeHtml(patientCode)}</p>
    <p><strong>CIN:</strong> ${escapeHtml(patientCin)}</p>
    <p><strong>Age:</strong> ${escapeHtml(patientAgeLabel)}</p>
  </div>

  ${notes ? `<h2>Notes</h2><p class="muted">${escapeHtml(notes)}</p>` : ''}

  <h2>Medicaments</h2>
  <table>
    <thead>
      <tr>
        <th>Nom</th>
        <th>Dosage</th>
        <th>Forme</th>
        <th>Quantite</th>
        <th>Frequence</th>
        <th>Periode</th>
        <th>Date debut</th>
        <th>Date fin</th>
        <th>Instructions</th>
      </tr>
    </thead>
    <tbody>
      ${rows || '<tr><td colspan="9">Aucun medicament.</td></tr>'}
    </tbody>
  </table>
</body>
</html>`
}

export function printPrescription(payload: PrintPrescriptionPayload): boolean {
  const printWindow = window.open('', '_blank', 'width=1100,height=800')
  if (!printWindow) {
    return false
  }

  const html = buildPrintHtml(payload)
  printWindow.document.open()
  printWindow.document.write(html)
  printWindow.document.close()
  printWindow.focus()
  printWindow.print()
  printWindow.close()
  return true
}
