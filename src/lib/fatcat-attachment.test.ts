import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import {
  EAR_LEFT_BASE,
  EAR_RIGHT_BASE,
  appendageScaleDelta,
  detachedEarGroupGap,
  earBaseAttachmentGap,
  earFollowRotationDelta,
  tailBaseAttachmentGap,
} from './fatcat-attachment'
import {
  CLICK_REACTION_DURATION_MS,
  FOLLOW_DELAY_MS,
  IDLE_LIFE_DURATION_MS,
  clickReactionPose,
  createDelayedSignal,
  earTwitchRotation,
  earTwitchSchedule,
  flightTiltAt,
  followThroughPose,
  idleLifePose,
} from './fatcat-motion'

const avatarMain = readFileSync(fileURLToPath(new URL('../avatar-main.tsx', import.meta.url)), 'utf8')
const avatarStyles = readFileSync(fileURLToPath(new URL('../avatar-styles.css', import.meta.url)), 'utf8')

const ATTACHMENT_TOLERANCE = 0.001
const EAR_TWITCH_SEED = 0xfa7ca7
const earTwitches = earTwitchSchedule(EAR_TWITCH_SEED, 40)

type FrameSample = {
  label: string
  bodyScale: number
  bodyRotationDeg: number
  earFollowDeltaDeg: number
  tailBaseDeltaDeg: number
  tailScaleDelta: number
  earTwitchDeg: number
}

function sampleIdleFrames(step = 20): FrameSample[] {
  const frames: FrameSample[] = []
  for (let t = 0; t <= IDLE_LIFE_DURATION_MS; t += step) {
    const pose = idleLifePose(t)
    const follow = followThroughPose(t)
    const bodyRotationDeg = pose.bodyRotationDeg
    frames.push({
      label: `idle@${t}ms`,
      bodyScale: pose.bodyScale,
      bodyRotationDeg,
      earFollowDeltaDeg: earFollowRotationDelta(bodyRotationDeg, follow.earRotationDeg),
      tailBaseDeltaDeg: earFollowRotationDelta(bodyRotationDeg, follow.tailBaseDeg),
      tailScaleDelta: appendageScaleDelta(pose.bodyScale, follow.tailScale),
      earTwitchDeg: earTwitchRotation(t % (earTwitches[earTwitches.length - 1] + 4000), earTwitches),
    })
  }
  return frames
}

function sampleFlightFrames(): FrameSample[] {
  const duration = 2600
  const maxTilt = 8
  const signal = createDelayedSignal()
  const frames: FrameSample[] = []
  for (let t = 0; t <= duration; t += 40) {
    const tilt = flightTiltAt(t, duration, maxTilt)
    signal.push(t, tilt)
    const pose = idleLifePose(t)
    const follow = followThroughPose(t)
    const bodyScale = pose.bodyScale * 0.94
    const bodyRotationDeg = pose.bodyRotationDeg + tilt
    const earFlightTilt = signal.sampleAt(t - FOLLOW_DELAY_MS.ears)
    const tailBaseFlight = signal.sampleAt(t - FOLLOW_DELAY_MS.tailBase)
    frames.push({
      label: `flight@${t}ms`,
      bodyScale,
      bodyRotationDeg,
      earFollowDeltaDeg: earFollowRotationDelta(bodyRotationDeg, follow.earRotationDeg + earFlightTilt),
      tailBaseDeltaDeg: earFollowRotationDelta(bodyRotationDeg, follow.tailBaseDeg + tailBaseFlight),
      tailScaleDelta: appendageScaleDelta(bodyScale, follow.tailScale * 0.92),
      earTwitchDeg: 0,
    })
  }
  return frames
}

function sampleClickFrames(): FrameSample[] {
  const frames: FrameSample[] = []
  for (let t = 0; t <= CLICK_REACTION_DURATION_MS; t += 15) {
    const reaction = clickReactionPose(t)
    const bodyScale = reaction.bodyScale
    frames.push({
      label: `click@${t}ms`,
      bodyScale,
      bodyRotationDeg: 0,
      earFollowDeltaDeg: 0,
      tailBaseDeltaDeg: 0,
      tailScaleDelta: 1,
      earTwitchDeg: 0,
    })
  }
  return frames
}

const expressionFrames: FrameSample[] = [
  { label: 'neutral', bodyScale: 1, bodyRotationDeg: 0, earFollowDeltaDeg: 0, tailBaseDeltaDeg: 0, tailScaleDelta: 1, earTwitchDeg: 0 },
  { label: 'thinking', bodyScale: 1, bodyRotationDeg: -3, earFollowDeltaDeg: 1.5, tailBaseDeltaDeg: 1, tailScaleDelta: 1, earTwitchDeg: 0 },
  { label: 'listening', bodyScale: 1.02, bodyRotationDeg: 0, earFollowDeltaDeg: 0, tailBaseDeltaDeg: 0, tailScaleDelta: 1, earTwitchDeg: 0 },
  { label: 'suspicious', bodyScale: 1, bodyRotationDeg: 2, earFollowDeltaDeg: -1, tailBaseDeltaDeg: -0.5, tailScaleDelta: 1, earTwitchDeg: 0 },
  { label: 'celebrate', bodyScale: 1.06, bodyRotationDeg: 5, earFollowDeltaDeg: 2, tailBaseDeltaDeg: 1.5, tailScaleDelta: 0.98, earTwitchDeg: 0 },
  { label: 'sleeping', bodyScale: 0.98, bodyRotationDeg: -1, earFollowDeltaDeg: 0.5, tailBaseDeltaDeg: 0, tailScaleDelta: 1, earTwitchDeg: 0 },
]

function assertFrameAttachment(frame: FrameSample) {
  for (const base of [EAR_LEFT_BASE, EAR_RIGHT_BASE]) {
    const gap = earBaseAttachmentGap(
      frame.bodyScale,
      frame.bodyRotationDeg,
      frame.earFollowDeltaDeg + frame.earTwitchDeg,
      base,
    )
    expect(gap, frame.label).toBeLessThan(ATTACHMENT_TOLERANCE)
  }
  const tailGap = tailBaseAttachmentGap(
    frame.bodyScale,
    frame.bodyRotationDeg,
    frame.tailBaseDeltaDeg,
    frame.tailScaleDelta,
  )
  expect(tailGap, frame.label).toBeLessThan(ATTACHMENT_TOLERANCE)
}

describe('FatCat appendage attachment', () => {
  it('keeps ear bases pinned when follow-through rotates around each ear base', () => {
    for (const frame of [
      ...sampleIdleFrames(),
      ...sampleFlightFrames(),
      ...sampleClickFrames(),
      ...expressionFrames,
    ]) {
      assertFrameAttachment(frame)
    }
  })

  it('shows the old detached ear group would have separated during idle expansion', () => {
    const t = 560
    const pose = idleLifePose(t)
    const follow = followThroughPose(t)
    const gap = detachedEarGroupGap(
      pose.bodyScale,
      pose.bodyRotationDeg,
      follow.earScale,
      follow.earRotationDeg,
      EAR_LEFT_BASE,
    )
    expect(gap).toBeGreaterThan(1)
  })

  it('keeps the shared frame transform contract in CSS', () => {
    expect(avatarStyles).toMatch(/\.fatcat-avatar-frame[\s\S]*--fatcat-body-scale/)
    expect(avatarStyles).toMatch(/\.fatcat-avatar-frame[\s\S]*--fatcat-body-rotation/)
    expect(avatarStyles).not.toMatch(/\.fatcat-avatar \{[\s\S]*--fatcat-body-scale/)
    expect(avatarStyles).not.toMatch(/\.fatcat-ears-follow/)
    expect(avatarStyles).toMatch(/\.fatcat-ear-left[\s\S]*-75px -62px/)
    expect(avatarStyles).toMatch(/\.fatcat-ear-right[\s\S]*75px -62px/)
    expect(avatarStyles).toMatch(/\.fatcat-tail-follow[\s\S]*96px 53px/)
    expect(avatarStyles).not.toMatch(/\.fatcat-ears \{[\s\S]*transform-origin:\s*0 0/)
  })

  it('publishes delta follow variables from the web surface', () => {
    expect(avatarMain).toContain('earFollowRotationDelta')
    expect(avatarMain).toContain('appendageScaleDelta')
    expect(avatarMain).toContain('--fatcat-ear-follow-rotation')
    expect(avatarMain).toContain('--fatcat-ear-perk-rotation')
    expect(avatarMain).not.toContain('--fatcat-ear-scale')
    expect(avatarMain).not.toMatch(/--fatcat-ear-perk[^-]/)
    expect(avatarMain).not.toContain('fatcat-ears-follow')
  })
})
