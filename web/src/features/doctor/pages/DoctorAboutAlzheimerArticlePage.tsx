import { Link, useNavigate, useParams } from 'react-router-dom'

import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { SectionCard } from '../../../shared/ui/SectionCard'
import {
  aboutAlzheimerPageContent,
  findAboutAlzheimerArticleById,
  findAboutAlzheimerCategory,
} from './aboutAlzheimerSections'

export function DoctorAboutAlzheimerArticlePage() {
  const navigate = useNavigate()
  const { articleId } = useParams()
  const article = findAboutAlzheimerArticleById(articleId)
  const category = findAboutAlzheimerCategory(article?.categoryId)

  if (!article) {
    return (
      <DoctorShellLayout title={aboutAlzheimerPageContent.title}>
        <div className="about-alzheimer-page">
          <AppHeader
            actions={
              <Link className="btn btn-outline" to="/about-alzheimer">
                Retour
              </Link>
            }
            subtitle={aboutAlzheimerPageContent.subtitle}
            title="Article introuvable"
          />
          <SectionCard title="Article introuvable">
            <p className="section-paragraph">
              L’article demandé est introuvable.
            </p>
          </SectionCard>
        </div>
      </DoctorShellLayout>
    )
  }

  return (
    <DoctorShellLayout title={aboutAlzheimerPageContent.title}>
      <div className="about-alzheimer-page">
        <AppHeader
          actions={
            <button
              className="btn btn-outline"
              onClick={() => navigate('/about-alzheimer')}
              type="button"
            >
              Retour
            </button>
          }
          subtitle={category?.label ?? aboutAlzheimerPageContent.subtitle}
          title={article.title}
        />

        <SectionCard title={article.title}>
          <article className="about-alzheimer-detail">
            <div className="about-alzheimer-detail-head">
              <span aria-hidden className="about-alzheimer-detail-icon">
                {article.icon}
              </span>
              <div className="about-alzheimer-detail-meta">
                {category && (
                  <span className="about-alzheimer-category-chip">
                    <span aria-hidden>{category.icon}</span>
                    {category.label}
                  </span>
                )}
                <span className="about-alzheimer-read-time">
                  {article.readTime}
                </span>
              </div>
            </div>

            <p className="section-paragraph about-alzheimer-detail-summary">
              {article.summary}
            </p>

            {article.sections.map((section) => {
              return (
                <section
                  className="about-alzheimer-detail-section"
                  key={section.heading}
                >
                  <h4>{section.heading}</h4>
                  <p className="section-paragraph">{section.content}</p>
                </section>
              )
            })}

            {article.tips.length > 0 && (
              <section className="about-alzheimer-tips">
                <h4>{article.tipsTitle}</h4>
                <ul>
                  {article.tips.map((tip) => {
                    return <li key={tip}>{tip}</li>
                  })}
                </ul>
              </section>
            )}
          </article>
        </SectionCard>

        <SectionCard
          className="about-alzheimer-important-card"
          title={aboutAlzheimerPageContent.importantMessage.title}
        >
          <p className="section-paragraph">
            {aboutAlzheimerPageContent.importantMessage.description}
          </p>
        </SectionCard>
      </div>
    </DoctorShellLayout>
  )
}
