import bundledDefinition from '../../public/fatcat.avatar.json'
import { describe, expect, it } from 'vitest'
import {
  avatarAnimationForState,
  canTransition,
  type FatCatPresenceState,
  type StateTransition,
  transitionState,
} from './fatcat-presence'
import { decideInterruption } from './interruption'
import { classifyAction, enforceAction, type ActionRequest } from './risk'
import { verifyAction } from './verification'
import { buildObservation } from './observation'

describe('FatCat presence domain', () => {
  it('maps every semantic state to a real FatCat animation or expression', () => {
    const validAnimations = new Set(bundledDefinition.animationOrder)
    const validExpressions = new Set(bundledDefinition.expressionOrder)

    for (const animation of Object.values(avatarAnimationForState)) {
      expect(validAnimations.has(animation.animation) || validExpressions.has(animation.expression ?? '')).toBe(true)
    }

    expect(avatarAnimationForState.idle.animation).toBe('idle')
    expect(avatarAnimationForState.listening.animation).toBe('listening')
    expect(avatarAnimationForState.understanding.animation).toBe('thinking')
    expect(avatarAnimationForState.planning.animation).toBe('thinking')
    expect(avatarAnimationForState.acting.animation).toBe('working')
    expect(avatarAnimationForState.searching.animation).toBe('searching')
    expect(avatarAnimationForState.celebrating.animation).toBe('celebrate')
    expect(avatarAnimationForState.recovering.animation).toBe('suspicious')
    expect(avatarAnimationForState.sleeping.animation).toBe('sleeping')
  })

  it('allows honest workflow transitions and rejects shortcuts', () => {
    expect(canTransition('acting', 'verifying')).toBe(true)
    expect(canTransition('verifying', 'celebrating')).toBe(true)
    expect(canTransition('asking_permission', 'listening')).toBe(true)
    expect(canTransition('acting', 'celebrating')).toBe(false)

    const transition: StateTransition = transitionState('acting', 'celebrating', 'executor said done')
    expect(transition.accepted).toBe(false)
    expect(transition.state).toBe('acting')
  })

  it('classifies actions and requires approval for medium and high risk', () => {
    const low: ActionRequest = { id: 'inspect', kind: 'inspect_state', label: 'Inspect state' }
    const medium: ActionRequest = { id: 'type', kind: 'type_text', label: 'Type text' }
    const high: ActionRequest = { id: 'send', kind: 'send', label: 'Send message' }

    expect(classifyAction(low)).toBe('low')
    expect(enforceAction(low, false).allowed).toBe(true)
    expect(enforceAction(medium, false)).toMatchObject({ allowed: false, requiresApproval: true })
    expect(enforceAction(medium, true).allowed).toBe(true)
    expect(enforceAction(high, true)).toMatchObject({ allowed: false, requiresApproval: true })
  })

  it('interrupts only for actionable, confident reasons outside cooldown', () => {
    expect(decideInterruption({ reason: 'verified_completion', confidence: 0.95, inCooldown: false, userIsTyping: false }).interrupt).toBe(true)
    expect(decideInterruption({ reason: 'directly_relevant_discovery', confidence: 0.61, inCooldown: false, userIsTyping: false }).interrupt).toBe(false)
    expect(decideInterruption({ reason: 'serious_error', confidence: 0.95, inCooldown: true, userIsTyping: false }).interrupt).toBe(false)
    expect(decideInterruption({ reason: 'dangerous_action', confidence: 0.99, inCooldown: false, userIsTyping: true }).interrupt).toBe(false)
  })

  it('celebrates only when observed verification matches the expected result', () => {
    expect(verifyAction({ expected: 'file exists', observed: 'file exists', confidence: 0.96 }).verified).toBe(true)
    expect(verifyAction({ expected: 'file exists', observed: 'file missing', confidence: 0.99 }).verified).toBe(false)
    expect(verifyAction({ expected: 'file exists', observed: 'file exists', confidence: 0.49 }).verified).toBe(false)
  })

  it('redacts private app context and never retains raw screenshots by default', () => {
    const observation = buildObservation({
      activeApp: '1Password',
      visibleWindow: 'Vault',
      task: 'Review credentials',
      privateApps: ['1Password'],
      detectedEvent: 'none',
    })

    expect(observation.privacy.redacted).toBe(true)
    expect(observation.activeApp).toBe('[private app]')
    expect(observation.visibleWindow).toBe('[redacted]')
    expect(observation.privacy.rawScreenshotRetained).toBe(false)
  })
})
