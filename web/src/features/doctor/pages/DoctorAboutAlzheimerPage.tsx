import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'

import { DoctorShellLayout } from '../../../shared/layouts/DoctorShellLayout'
import { AppHeader } from '../../../shared/ui/AppHeader'
import { EmptyState } from '../../../shared/ui/EmptyState'
import { SectionCard } from '../../../shared/ui/SectionCard'
import {
  type AboutAlzheimerArticle,
  type AboutAlzheimerCategory,
  aboutAlzheimerPageContent,
  findAboutAlzheimerCategory,
  getRecommendedAboutAlzheimerArticles,
} from './aboutAlzheimerSections'

const ALL_CATEGORIES_ID = 'all'

function normalizeSearchText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLocaleLowerCase('fr-FR')
}

function articleMatchesSearch(
  article: AboutAlzheimerArticle,
  category: AboutAlzheimerCategory | undefined,
  searchTerm: string,
): boolean {
  const query = normalizeSearchText(searchTerm.trim())
  if (query.length === 0) {
    return true
  }

  const searchableText = [
    article.title,
    article.description,
    article.summary,
    category?.label ?? '',
    ...article.tags,
  ].join(' ')

  return normalizeSearchText(searchableText).includes(query)
}

interface AboutAlzheimerArticleCardProps {
  article: AboutAlzheimerArticle
  category: AboutAlzheimerCategory | undefined
}

function AboutAlzheimerArticleCard({
  article,
  category,
}: AboutAlzheimerArticleCardProps) {
  const visibleTags = article.tags.slice(0, 3)

  return (
    <Link className="about-alzheimer-card" to={`/about-alzheimer/${article.id}`}>
      <div className="about-alzheimer-card-head">
        <span aria-hidden className="about-alzheimer-card-icon">
          {article.icon}
        </span>
        <div className="about-alzheimer-card-meta">
          {category && (
            <span className="about-alzheimer-category-chip">
              <span aria-hidden>{category.icon}</span>
              {category.label}
            </span>
          )}
          <span className="about-alzheimer-read-time">{article.readTime}</span>
        </div>
      </div>

      <h4>{article.title}</h4>
      <p className="section-paragraph">{article.description}</p>

      {visibleTags.length > 0 && (
        <div className="about-alzheimer-tag-row">
          {visibleTags.map((tag) => {
            return (
              <span className="fact-chip" key={tag}>
                {tag}
              </span>
            )
          })}
        </div>
      )}

      <span className="btn btn-primary about-alzheimer-read-button">Lire</span>
    </Link>
  )
}

export function DoctorAboutAlzheimerPage() {
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategoryId, setSelectedCategoryId] =
    useState(ALL_CATEGORIES_ID)

  const recommendedArticles = useMemo(() => {
    return getRecommendedAboutAlzheimerArticles()
  }, [])

  const filteredArticles = useMemo(() => {
    return aboutAlzheimerPageContent.articles.filter((article) => {
      const category = findAboutAlzheimerCategory(article.categoryId)
      const matchesCategory =
        selectedCategoryId === ALL_CATEGORIES_ID ||
        article.categoryId === selectedCategoryId

      return matchesCategory && articleMatchesSearch(article, category, searchTerm)
    })
  }, [searchTerm, selectedCategoryId])

  return (
    <DoctorShellLayout title={aboutAlzheimerPageContent.title}>
      <div className="about-alzheimer-page">
        <AppHeader
          subtitle={aboutAlzheimerPageContent.subtitle}
          title={aboutAlzheimerPageContent.title}
        />

        <SectionCard title="Introduction">
          <p className="section-paragraph">
            {aboutAlzheimerPageContent.introduction}
          </p>
        </SectionCard>

        <SectionCard title="Rechercher">
          <div className="about-alzheimer-controls">
            <label
              className="about-alzheimer-search-label"
              htmlFor="about-alzheimer-search"
            >
              Rechercher dans les articles
            </label>
            <input
              className="input-control about-alzheimer-search-input"
              id="about-alzheimer-search"
              onChange={(event) => setSearchTerm(event.target.value)}
              placeholder={aboutAlzheimerPageContent.searchPlaceholder}
              type="search"
              value={searchTerm}
            />

            <div className="about-alzheimer-filter-row" role="list">
              <button
                className={
                  selectedCategoryId === ALL_CATEGORIES_ID
                    ? 'chip-button is-selected'
                    : 'chip-button'
                }
                onClick={() => setSelectedCategoryId(ALL_CATEGORIES_ID)}
                type="button"
              >
                Tous
              </button>
              {aboutAlzheimerPageContent.categories.map((category) => {
                return (
                  <button
                    className={
                      selectedCategoryId === category.id
                        ? 'chip-button is-selected'
                        : 'chip-button'
                    }
                    key={category.id}
                    onClick={() => setSelectedCategoryId(category.id)}
                    type="button"
                  >
                    <span aria-hidden>{category.icon}</span>
                    {category.label}
                  </button>
                )
              })}
            </div>

            {aboutAlzheimerPageContent.popularSearches.length > 0 && (
              <div className="about-alzheimer-popular-searches">
                <span>Recherches populaires</span>
                <div className="chip-row">
                  {aboutAlzheimerPageContent.popularSearches.map((search) => {
                    return (
                      <button
                        className="chip-button"
                        key={search}
                        onClick={() => setSearchTerm(search)}
                        type="button"
                      >
                        {search}
                      </button>
                    )
                  })}
                </div>
              </div>
            )}
          </div>
        </SectionCard>

        {recommendedArticles.length > 0 && (
          <SectionCard title="Articles recommandés">
            <div className="about-alzheimer-grid">
              {recommendedArticles.map((article) => {
                return (
                  <AboutAlzheimerArticleCard
                    article={article}
                    category={findAboutAlzheimerCategory(article.categoryId)}
                    key={article.id}
                  />
                )
              })}
            </div>
          </SectionCard>
        )}

        <SectionCard title="Tous les articles">
          {filteredArticles.length > 0 ? (
            <div className="about-alzheimer-grid">
              {filteredArticles.map((article) => {
                return (
                  <AboutAlzheimerArticleCard
                    article={article}
                    category={findAboutAlzheimerCategory(article.categoryId)}
                    key={article.id}
                  />
                )
              })}
            </div>
          ) : (
            <EmptyState
              iconLabel="INFO"
              message="Aucun article ne correspond à cette recherche."
              title="Aucun article trouvé"
            />
          )}
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
