import aboutAppContent from '../../../data/aboutAppContent'

export type AboutSectionKey = 'objective' | 'users' | 'features'

export interface AboutCardItem {
  icon: string
  title: string
  description: string
  details: string
}

export interface AboutCardSection {
  key: AboutSectionKey
  title: string
  cards: AboutCardItem[]
}

interface AboutPageContent {
  title: string
  subtitle: string
  introduction: string
  objectiveTitle: string
  objectiveDescription: string
  usersTitle: string
  featuresTitle: string
  benefitsTitle: string
  benefitsDescription: string
  benefitsItems: string[]
  importantMessageTitle: string
  importantMessageDescription: string
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

function asCardArray(value: unknown): AboutCardItem[] {
  if (!Array.isArray(value)) {
    return []
  }

  return value.map((entry) => {
    const record = asRecord(entry)
    return {
      icon: asString(record.icon),
      title: asString(record.title),
      description: asString(record.description),
      details: asString(record.details),
    }
  })
}

const content = asRecord(aboutAppContent)
const objective = asRecord(content.objective)
const users = asRecord(content.users)
const features = asRecord(content.features)
const benefits = asRecord(content.benefits)
const importantMessage = asRecord(content.importantMessage)

export const aboutPageContent: AboutPageContent = {
  title: asString(content.title),
  subtitle: asString(content.subtitle),
  introduction: asString(content.introduction),
  objectiveTitle: asString(objective.title),
  objectiveDescription: asString(objective.description),
  usersTitle: asString(users.title),
  featuresTitle: asString(features.title),
  benefitsTitle: asString(benefits.title),
  benefitsDescription: asString(benefits.description),
  benefitsItems: asStringArray(benefits.items),
  importantMessageTitle: asString(importantMessage.title),
  importantMessageDescription: asString(importantMessage.description),
}

export const aboutCardSections: AboutCardSection[] = [
  {
    key: 'objective',
    title: asString(objective.title),
    cards: asCardArray(objective.items),
  },
  {
    key: 'users',
    title: asString(users.title),
    cards: asCardArray(users.cards),
  },
  {
    key: 'features',
    title: asString(features.title),
    cards: asCardArray(features.cards),
  },
]

export function findAboutSectionByKey(
  key: string | undefined,
): AboutCardSection | undefined {
  if (!key) {
    return undefined
  }
  return aboutCardSections.find((section) => section.key === key)
}

export function findAboutCardDetails(
  sectionKey: string | undefined,
  indexText: string | undefined,
): { sectionTitle: string; card: AboutCardItem } | undefined {
  const section = findAboutSectionByKey(sectionKey)
  if (!section) {
    return undefined
  }

  const parsedIndex = Number.parseInt(indexText ?? '', 10)
  if (Number.isNaN(parsedIndex) || parsedIndex < 0) {
    return undefined
  }

  const card = section.cards[parsedIndex]
  if (!card) {
    return undefined
  }

  return {
    sectionTitle: section.title,
    card,
  }
}
