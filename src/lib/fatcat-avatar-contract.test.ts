import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import bundledDefinition from '../../public/fatcat.avatar.json'
import type { AvatarDefinition } from '@bible-strong/avatar-core'
import { describe, expect, it } from 'vitest'

const definition = bundledDefinition as unknown as AvatarDefinition
const avatarMain = readFileSync(fileURLToPath(new URL('../avatar-main.tsx', import.meta.url)), 'utf8')
const avatarStyles = readFileSync(fileURLToPath(new URL('../avatar-styles.css', import.meta.url)), 'utf8')
const appMain = readFileSync(
  fileURLToPath(new URL('../../macos/FatCat/Sources/FatCat/AppMain.swift', import.meta.url)),
  'utf8',
)
const packageManifest = readFileSync(
  fileURLToPath(new URL('../../macos/FatCat/Package.swift', import.meta.url)),
  'utf8',
)

describe('FatCat avatar visual contract', () => {
  it('keeps the original circular body geometry while changing only the palette and name', () => {
    expect(definition.name).toBe('FatCat')
    expect(definition.body.primary).toMatchObject({
      type: 'sphere',
      width: 240,
      height: 240,
      depth: 240.03671875,
      roundness: 1,
    })
    expect(definition.colors).toEqual({ body: '#f28c38', eyes: '#111316' })
  })

  it('preserves the original expression and animation catalog', () => {
    expect(definition.expressionOrder).toHaveLength(28)
    expect(definition.animationOrder).toHaveLength(23)
    expect(new Set(definition.expressionOrder)).toEqual(new Set(Object.keys(definition.expressions)))
    expect(new Set(definition.animationOrder)).toEqual(new Set(Object.keys(definition.animations)))
  })

  it('covers every FatCat life animation with the original catalog', () => {
    for (const key of ['idle', 'listening', 'thinking', 'working', 'celebrate', 'suspicious', 'curious', 'drowsy', 'sleeping']) {
      expect(definition.animations[key as keyof typeof definition.animations]).toBeDefined()
    }
  })

  it('renders through the original React avatar packages, not a native 3D reinterpretation', () => {
    expect(avatarMain).toContain("from '@bible-strong/avatar-react'")
    expect(avatarMain).toContain("from '@bible-strong/avatar-core'")
    expect(avatarMain).toContain("../public/fatcat.avatar.json")
    expect(avatarMain).toContain('<Avatar')
    expect(avatarMain).toContain('fatcat-ears')
    expect(avatarMain).toContain('fatcat-tail')
    expect(appMain).not.toContain('FatCatAvatarRenderer')
    expect(appMain).not.toContain('SceneKit')
    expect(appMain).not.toContain('RealityKit')
    expect(appMain).not.toContain('import Metal')
    expect(packageManifest).toContain('exclude: ["FatCatAvatar.swift"]')
  })

  it('keeps the avatar web surface visually transparent', () => {
    expect(avatarStyles).toMatch(/html[\s\S]*background:\s*transparent/)
    expect(avatarStyles).toMatch(/body[\s\S]*background:\s*transparent/)
    expect(avatarStyles).toContain('.fatcat-avatar-surface')
    expect(avatarStyles).toContain('background: transparent')
    expect(appMain).toContain('drawsBackground')
    expect(appMain).toContain('underPageBackgroundColor = .clear')
  })

  it('keeps the avatar surface free of an artificial glow', () => {
    expect(avatarStyles).not.toContain('.fatcat-avatar-surface::before')
    expect(avatarStyles).not.toMatch(/backdrop-filter:\s*blur\(/)
    expect(avatarStyles).not.toContain('rgba(255, 255, 255')
  })
})
