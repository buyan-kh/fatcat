import {
  parseAvatarDefinition,
  type AvatarDefinition,
} from '@bible-strong/avatar-core'

export type { AvatarDefinition }

export type DefinitionSummary = {
  name: string
  bodyType: string
  dimensions: string
  bodyColor: string
  eyeColor: string
  expressionCount: number
  animationCount: number
}

export function summarizeDefinition(definition: AvatarDefinition): DefinitionSummary {
  const primary = definition.body.primary

  return {
    name: definition.name?.trim() || 'Unnamed avatar',
    bodyType: primary.type,
    dimensions: `${Math.round(primary.width)} × ${Math.round(primary.height)} × ${Math.round(primary.depth)}`,
    bodyColor: definition.colors.body,
    eyeColor: definition.colors.eyes,
    expressionCount: definition.expressionOrder.length,
    animationCount: definition.animationOrder.length,
  }
}

export type ImportedDefinitionResult =
  | { ok: true; definition: Readonly<AvatarDefinition> }
  | { ok: false; message: string }

export function normalizeImportedDefinition(text: string): ImportedDefinitionResult {
  const parsed = parseAvatarDefinition(text)

  if (!parsed.ok) {
    return {
      ok: false,
      message: 'This file is not a valid Bible Strong avatar definition.',
    }
  }

  return { ok: true, definition: parsed.value }
}
