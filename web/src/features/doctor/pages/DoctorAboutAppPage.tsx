import { Link } from 'react-router-dom'

import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { SectionCard } from '../../../shared/ui/SectionCard'
import { aboutCardSections, aboutPageContent } from './aboutAppSections'

function renderCardLink(
  section: (typeof aboutCardSections)[number],
  index: number,
) {
  const card = section.cards[index]
  if (!card) {
    return null
  }

  const hasDescription = card.description.trim().length > 0

  return (
    <Link
      className="about-app-card"
      key={`${section.key}-${index}`}
      to={`/about-app/detail/${section.key}/${index}`}
    >
      <span aria-hidden className="about-app-card-icon">
        {card.icon}
      </span>
      <h4>{card.title}</h4>
      {hasDescription && <p className="section-paragraph">{card.description}</p>}
      <span className="about-app-card-link">Voir plus</span>
    </Link>
  )
}

export function DoctorAboutAppPage() {
  return (
    <DoctorShellLayout title={aboutPageContent.title}>
      <div className="about-app-page">
        <AppHeader
          subtitle={aboutPageContent.subtitle}
          title={aboutPageContent.title}
        />

        <SectionCard title={aboutPageContent.objectiveTitle}>
          <p className="section-paragraph">{aboutPageContent.introduction}</p>
          <p className="section-paragraph about-app-objective-description">
            {aboutPageContent.objectiveDescription}
          </p>
          <div className="about-app-card-grid">
            {aboutCardSections[0]?.cards.map((_, index) => {
              return renderCardLink(aboutCardSections[0], index)
            })}
          </div>
        </SectionCard>

        <SectionCard title={aboutPageContent.usersTitle}>
          <div className="about-app-card-grid">
            {aboutCardSections[1]?.cards.map((_, index) => {
              return renderCardLink(aboutCardSections[1], index)
            })}
          </div>
        </SectionCard>

        <SectionCard title={aboutPageContent.featuresTitle}>
          <div className="about-app-card-grid">
            {aboutCardSections[2]?.cards.map((_, index) => {
              return renderCardLink(aboutCardSections[2], index)
            })}
          </div>
        </SectionCard>

        <SectionCard title={aboutPageContent.benefitsTitle}>
          <p className="section-paragraph">{aboutPageContent.benefitsDescription}</p>
          <ul className="about-app-benefits-list">
            {aboutPageContent.benefitsItems.map((item) => {
              return <li key={item}>{item}</li>
            })}
          </ul>
        </SectionCard>

        <SectionCard
          className="about-app-important-card"
          title={aboutPageContent.importantMessageTitle}
        >
          <p className="section-paragraph">
            {aboutPageContent.importantMessageDescription}
          </p>
        </SectionCard>
      </div>
    </DoctorShellLayout>
  )
}
