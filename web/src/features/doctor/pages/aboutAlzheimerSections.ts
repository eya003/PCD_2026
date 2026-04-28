import aboutAlzheimerContent from '../../../data/aboutAlzheimerContent'

export interface AboutAlzheimerCategory {
  id: string
  label: string
  icon: string
  description: string
}

export interface AboutAlzheimerArticleSection {
  heading: string
  content: string
}

export interface AboutAlzheimerArticle {
  id: string
  categoryId: string
  icon: string
  title: string
  description: string
  readTime: string
  tags: string[]
  summary: string
  sections: AboutAlzheimerArticleSection[]
  tipsTitle: string
  tips: string[]
}

export interface AboutAlzheimerImportantMessage {
  title: string
  description: string
}

export interface AboutAlzheimerPageContent {
  title: string
  subtitle: string
  introduction: string
  searchPlaceholder: string
  categories: AboutAlzheimerCategory[]
  popularSearches: string[]
  recommendedArticleIds: string[]
  articles: AboutAlzheimerArticle[]
  importantMessage: AboutAlzheimerImportantMessage
}

type AnyRecord = Record<string, unknown>

function asRecord(value: unknown): AnyRecord {
  if (value && typeof value === 'object') {
    return value as AnyRecord
  }
  return {}
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : ''
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return []
  }
  return value
    .map((entry) => asString(entry))
    .filter((entry) => entry.trim().length > 0)
}

function asCategoryArray(value: unknown): AboutAlzheimerCategory[] {
  if (!Array.isArray(value)) {
    return []
  }

  return value.map((entry) => {
    const record = asRecord(entry)
    return {
      id: asString(record.id),
      label: asString(record.label),
      icon: asString(record.icon),
      description: asString(record.description),
    }
  })
}

function asArticleSections(value: unknown): AboutAlzheimerArticleSection[] {
  if (!Array.isArray(value)) {
    return []
  }

  return value.map((entry) => {
    const record = asRecord(entry)
    return {
      heading: asString(record.heading),
      content: asString(record.content),
    }
  })
}

function asArticleArray(value: unknown): AboutAlzheimerArticle[] {
  if (!Array.isArray(value)) {
    return []
  }

  return value.map((entry) => {
    const record = asRecord(entry)
    return {
      id: asString(record.id),
      categoryId: asString(record.categoryId),
      icon: asString(record.icon),
      title: asString(record.title),
      description: asString(record.description),
      readTime: asString(record.readTime),
      tags: asStringArray(record.tags),
      summary: asString(record.summary),
      sections: asArticleSections(record.sections),
      tipsTitle: asString(record.tipsTitle),
      tips: asStringArray(record.tips),
    }
  })
}

const content = asRecord(aboutAlzheimerContent)
const importantMessage = asRecord(content.importantMessage)

export const aboutAlzheimerPageContent: AboutAlzheimerPageContent = {
  title: asString(content.title),
  subtitle: asString(content.subtitle),
  introduction: asString(content.introduction),
  searchPlaceholder: asString(content.searchPlaceholder),
  categories: asCategoryArray(content.categories),
  popularSearches: asStringArray(content.popularSearches),
  recommendedArticleIds: asStringArray(content.recommendedArticleIds),
  articles: asArticleArray(content.articles),
  importantMessage: {
    title: asString(importantMessage.title),
    description: asString(importantMessage.description),
  },
}

export function findAboutAlzheimerCategory(
  categoryId: string | undefined,
): AboutAlzheimerCategory | undefined {
  if (!categoryId) {
    return undefined
  }

  return aboutAlzheimerPageContent.categories.find((category) => {
    return category.id === categoryId
  })
}

export function findAboutAlzheimerArticleById(
  articleId: string | undefined,
): AboutAlzheimerArticle | undefined {
  if (!articleId) {
    return undefined
  }

  return aboutAlzheimerPageContent.articles.find((article) => {
    return article.id === articleId
  })
}

export function getRecommendedAboutAlzheimerArticles(): AboutAlzheimerArticle[] {
  return aboutAlzheimerPageContent.recommendedArticleIds
    .map((articleId) => findAboutAlzheimerArticleById(articleId))
    .filter((article): article is AboutAlzheimerArticle => Boolean(article))
}
