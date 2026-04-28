import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { SectionCard } from '../../../shared/ui/SectionCard'

export function DoctorAiPage() {
  return (
    <DoctorShellLayout title="Module IA">
      <AppHeader
        subtitle="Module IA medecin (alignement navigation Flutter)."
        title="Module IA"
      />

      <SectionCard title="Module IA">
        <p className="section-paragraph">
          Cette section est prete dans la navigation medecin. Le contenu metier IA
          sera branche dans un sprint dedie.
        </p>
      </SectionCard>
    </DoctorShellLayout>
  )
}
