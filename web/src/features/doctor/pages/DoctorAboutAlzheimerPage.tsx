import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { SectionCard } from '../../../shared/ui/SectionCard'

export function DoctorAboutAlzheimerPage() {
  return (
    <DoctorShellLayout title="A propos d Alzheimer">
      <AppHeader
        subtitle="Rappel simple, sans contenu medical avance."
        title="A propos d Alzheimer"
      />

      <SectionCard title="Information generale">
        <p className="section-paragraph">
          La maladie d Alzheimer est une affection neurodegenerative progressive
          qui touche la memoire, l orientation et certaines capacites cognitives.
          Cette page est un repere informatif rapide; le contenu medical detaille
          sera complete dans un sprint dedie.
        </p>
      </SectionCard>
    </DoctorShellLayout>
  )
}
