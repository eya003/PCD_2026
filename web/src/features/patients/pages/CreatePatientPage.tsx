import { type FormEvent, useState } from 'react'
import { useNavigate } from 'react-router-dom'

import { useAuth } from '../../../core/auth/useAuth'
import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { SectionCard } from '../../../shared/ui/SectionCard'
import { createPatient } from '../api/patientsApi'

function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return 'Impossible de creer le patient.'
}

export function CreatePatientPage() {
  const navigate = useNavigate()
  const { user } = useAuth()

  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [birthDate, setBirthDate] = useState('')
  const [cin, setCin] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)

    if (!user || user.role !== 'doctor') {
      setError('Action reservee au medecin.')
      return
    }

    if (!firstName.trim() || !lastName.trim() || !birthDate || !cin.trim()) {
      setError('Veuillez remplir tous les champs obligatoires.')
      return
    }

    if (cin.trim().length < 3) {
      setError('CIN invalide.')
      return
    }

    setIsSubmitting(true)
    try {
      const created = await createPatient({
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        birth_date: birthDate,
        cin: cin.trim(),
      })
      navigate(`/patients/${created.id}`, { replace: true })
    } catch (submitError) {
      setError(getErrorMessage(submitError))
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <DoctorShellLayout title="Ajouter patient">
      <AppHeader
        subtitle="Saisissez les informations obligatoires du patient."
        title="Nouveau patient"
      />

      <SectionCard title="Formulaire patient">
        <form className="auth-form" onSubmit={handleSubmit}>
          <label className="field-block">
            <span>Prenom</span>
            <input
              autoComplete="given-name"
              className="input-control"
              onChange={(event) => setFirstName(event.target.value)}
              type="text"
              value={firstName}
            />
          </label>

          <label className="field-block">
            <span>Nom</span>
            <input
              autoComplete="family-name"
              className="input-control"
              onChange={(event) => setLastName(event.target.value)}
              type="text"
              value={lastName}
            />
          </label>

          <label className="field-block">
            <span>Date de naissance</span>
            <input
              className="input-control"
              onChange={(event) => setBirthDate(event.target.value)}
              type="date"
              value={birthDate}
            />
          </label>

          <label className="field-block">
            <span>CIN</span>
            <input
              autoComplete="off"
              className="input-control"
              onChange={(event) => setCin(event.target.value)}
              type="text"
              value={cin}
            />
          </label>

          {error && (
            <div className="error-banner" role="alert">
              <p>{error}</p>
            </div>
          )}

          <div className="dialog-actions">
            <button
              className="btn btn-outline"
              disabled={isSubmitting}
              onClick={() => navigate('/patients')}
              type="button"
            >
              Annuler
            </button>
            <button className="btn btn-primary" disabled={isSubmitting} type="submit">
              {isSubmitting ? 'Creation...' : 'Ajouter patient'}
            </button>
          </div>
        </form>
      </SectionCard>
    </DoctorShellLayout>
  )
}
