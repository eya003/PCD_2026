import { Link, useNavigate, useParams } from 'react-router-dom'

import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { SectionCard } from '../../../shared/ui/SectionCard'
import { aboutPageContent, findAboutCardDetails } from './aboutAppSections'

export function DoctorAboutAppDetailPage() {
  const navigate = useNavigate()
  const { section, index } = useParams()
  const details = findAboutCardDetails(section, index)

  if (!details) {
    return (
      <DoctorShellLayout title={aboutPageContent.title}>
        <div className="about-app-page">
          <AppHeader
            subtitle={aboutPageContent.subtitle}
            title={aboutPageContent.title}
          />
          <SectionCard title="Contenu indisponible">
            <p className="section-paragraph">
              Le detail demande est introuvable.
            </p>
            <div className="about-app-detail-actions">
              <Link className="btn btn-outline" to="/about-app">
                Retour
              </Link>
            </div>
          </SectionCard>
        </div>
      </DoctorShellLayout>
    )
  }

  const { card, sectionTitle } = details
  const hasDescription = card.description.trim().length > 0

  return (
    <DoctorShellLayout title={aboutPageContent.title}>
      <div className="about-app-page">
        <AppHeader subtitle={sectionTitle} title={card.title} />

        <SectionCard title={sectionTitle}>
          <div className="about-app-detail-content">
            <span aria-hidden className="about-app-detail-icon">
              {card.icon}
            </span>
            <h4 className="about-app-detail-title">{card.title}</h4>
            {hasDescription && (
              <p className="section-paragraph about-app-detail-description">
                {card.description}
              </p>
            )}
            <p className="section-paragraph about-app-detail-text">
              {card.details}
            </p>
            <div className="about-app-detail-actions">
              <button
                className="btn btn-outline"
                onClick={() => navigate('/about-app')}
                type="button"
              >
                Retour
              </button>
            </div>
          </div>
        </SectionCard>
      </div>
    </DoctorShellLayout>
  )
}
