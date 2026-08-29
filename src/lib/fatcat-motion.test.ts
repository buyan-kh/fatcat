import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import {
  CLICK_REACTION_DURATION_MS,
  FOLLOW_DELAY_MS,
  IDLE_LIFE_DURATION_MS,
  NEUTRAL_POSE,
  clickReactionPose,
  createSeededRandom,
  earTwitchSchedule,
  followThroughPose,
  idleLifePose,
} from './fatcat-motion'

const avatarMain = readFileSync(fileURLToPath(new URL('../avatar-main.tsx', import.meta.url)), 'utf8')
const avatarStyles = readFileSync(fileURLToPath(new URL('../avatar-styles.css', import.meta.url)), 'utf8')

function sample(step = 10) {
  const poses = []
  for (let t = 0; t <= IDLE_LIFE_DURATION_MS; t += step) poses.push({ t, pose: idleLifePose(t) })
  return poses
}

describe('FatCat idle life loop', () => {
  it('runs for a calm 2.4 to 3.2 second cycle', () => {
    expect(IDLE_LIFE_DURATION_MS).toBeGreaterThanOrEqual(2400)
    expect(IDLE_LIFE_DURATION_MS).toBeLessThanOrEqual(3200)
  })

  it('crouches in anticipation, expands quickly, then settles', () => {
    const poses = sample()
    const scales = poses.map((p) => p.pose.bodyScale)
    const crouch = Math.min(...scales)
    const peak = Math.max(...scales)
    expect(crouch).toBeLessThanOrEqual(0.8)
    expect(peak).toBeGreaterThanOrEqual(1.05)
    expect(peak).toBeLessThanOrEqual(1.12)
    const crouchAt = poses.find((p) => p.pose.bodyScale === crouch)!.t
    const peakAt = poses.find((p) => p.pose.bodyScale === peak)!.t
    expect(crouchAt).toBeLessThan(peakAt)
    const settled = idleLifePose(IDLE_LIFE_DURATION_MS - 200)
    expect(settled.bodyScale).toBeCloseTo(1, 2)
  })

  it('keeps the body circular by only ever scaling uniformly', () => {
    for (const { pose } of sample()) {
      expect(typeof pose.bodyScale).toBe('number')
      expect('bodyScaleX' in pose).toBe(false)
      expect('bodyScaleY' in pose).toBe(false)
    }
  })

  it('enlarges the eyes vertically more than horizontally', () => {
    const poses = sample()
    const maxHeight = Math.max(...poses.map((p) => p.pose.eyeScaleY))
    const maxWidth = Math.max(...poses.map((p) => p.pose.eyeScaleX))
    expect(maxHeight).toBeGreaterThanOrEqual(1.1)
    expect(maxHeight).toBeLessThanOrEqual(1.2)
    expect(maxWidth).toBeGreaterThanOrEqual(1.02)
    expect(maxWidth).toBeLessThan(maxHeight)
  })

  it('leans the eyes left then sweeps through the right diagonal before settling upright', () => {
    const poses = sample()
    const minRotation = Math.min(...poses.map((p) => p.pose.eyeRotationDeg))
    const maxRotation = Math.max(...poses.map((p) => p.pose.eyeRotationDeg))
    expect(minRotation).toBeLessThanOrEqual(-15)
    expect(maxRotation).toBeGreaterThanOrEqual(15)
    const leanAt = poses.find((p) => p.pose.eyeRotationDeg === minRotation)!.t
    const sweepAt = poses.find((p) => p.pose.eyeRotationDeg === maxRotation)!.t
    expect(leanAt).toBeLessThan(sweepAt)
    expect(idleLifePose(IDLE_LIFE_DURATION_MS - 100).eyeRotationDeg).toBeCloseTo(0, 1)
  })

  it('keeps body rotation inside the gentle ±12 degree envelope', () => {
    for (const { pose } of sample()) {
      expect(Math.abs(pose.bodyRotationDeg)).toBeLessThanOrEqual(12)
    }
  })

  it('loops seamlessly', () => {
    const first = idleLifePose(0)
    const last = idleLifePose(IDLE_LIFE_DURATION_MS)
    const nearEnd = idleLifePose(IDLE_LIFE_DURATION_MS - 1)
    expect(last).toEqual(first)
    expect(nearEnd.bodyScale).toBeCloseTo(first.bodyScale, 2)
    expect(nearEnd.eyeRotationDeg).toBeCloseTo(first.eyeRotationDeg, 1)
  })

  it('is not a mechanical timer: motion eases rather than stepping', () => {
    const poses = sample(10)
    let maxJump = 0
    for (let i = 1; i < poses.length; i += 1) {
      maxJump = Math.max(maxJump, Math.abs(poses[i].pose.bodyScale - poses[i - 1].pose.bodyScale))
    }
    expect(maxJump).toBeLessThan(0.03)
  })
})

describe('FatCat ear and tail follow-through', () => {
  it('publishes delays inside the specified windows', () => {
    expect(FOLLOW_DELAY_MS.ears).toBeGreaterThanOrEqual(50)
    expect(FOLLOW_DELAY_MS.ears).toBeLessThanOrEqual(100)
    expect(FOLLOW_DELAY_MS.tailBase).toBeGreaterThanOrEqual(40)
    expect(FOLLOW_DELAY_MS.tailBase).toBeLessThanOrEqual(80)
    expect(FOLLOW_DELAY_MS.tailMid).toBeGreaterThanOrEqual(80)
    expect(FOLLOW_DELAY_MS.tailMid).toBeLessThanOrEqual(140)
    expect(FOLLOW_DELAY_MS.tailTip).toBeGreaterThanOrEqual(120)
    expect(FOLLOW_DELAY_MS.tailTip).toBeLessThanOrEqual(220)
  })

  it('ears follow the body with their delay instead of moving in sync', () => {
    const t = 900
    const follow = followThroughPose(t)
    const delayedBody = idleLifePose(t - FOLLOW_DELAY_MS.ears)
    expect(follow.earRotationDeg).toBeCloseTo(delayedBody.bodyRotationDeg, 5)
    const liveBody = idleLifePose(t)
    expect(follow.earRotationDeg).not.toBeCloseTo(liveBody.bodyRotationDeg, 1)
  })

  it('tail segments trail progressively and the tip overshoots slightly', () => {
    const t = 1200
    const follow = followThroughPose(t)
    expect(follow.tailBaseDeg).toBeCloseTo(idleLifePose(t - FOLLOW_DELAY_MS.tailBase).bodyRotationDeg, 5)
    expect(follow.tailMidDeg).toBeCloseTo(idleLifePose(t - FOLLOW_DELAY_MS.tailMid).bodyRotationDeg, 5)
    const tipSource = idleLifePose(t - FOLLOW_DELAY_MS.tailTip).bodyRotationDeg
    expect(Math.abs(follow.tailTipDeg)).toBeGreaterThan(Math.abs(tipSource))
    expect(Math.abs(follow.tailTipDeg)).toBeLessThanOrEqual(Math.abs(tipSource) * 1.3 + 0.001)
  })

  it('never lets appendages change the body scale', () => {
    const follow = followThroughPose(700)
    expect('bodyScale' in follow).toBe(false)
  })
})

describe('FatCat seeded randomness', () => {
  it('is deterministic for the same seed and different across seeds', () => {
    const a = createSeededRandom(42)
    const b = createSeededRandom(42)
    const c = createSeededRandom(7)
    const seqA = [a(), a(), a()]
    const seqB = [b(), b(), b()]
    const seqC = [c(), c(), c()]
    expect(seqA).toEqual(seqB)
    expect(seqA).not.toEqual(seqC)
    for (const value of seqA) {
      expect(value).toBeGreaterThanOrEqual(0)
      expect(value).toBeLessThan(1)
    }
  })

  it('schedules occasional ear twitches, not constant movement', () => {
    const schedule = earTwitchSchedule(42, 6)
    expect(schedule).toEqual(earTwitchSchedule(42, 6))
    expect(schedule).toHaveLength(6)
    for (let i = 1; i < schedule.length; i += 1) {
      const gap = schedule[i] - schedule[i - 1]
      expect(gap).toBeGreaterThanOrEqual(4000)
      expect(gap).toBeLessThanOrEqual(12000)
    }
  })
})

describe('FatCat click reaction', () => {
  it('reacts briefly and returns to neutral without any cursor input', () => {
    expect(clickReactionPose.length).toBe(1)
    const early = clickReactionPose(100)
    expect(early.bodyScale).toBeGreaterThan(1)
    expect(early.earPerk).toBeGreaterThan(0)
    expect(CLICK_REACTION_DURATION_MS).toBeLessThanOrEqual(600)
    const done = clickReactionPose(CLICK_REACTION_DURATION_MS)
    expect(done.bodyScale).toBeCloseTo(1, 3)
    expect(done.earPerk).toBeCloseTo(0, 3)
  })
})

describe('FatCat motion surface contract', () => {
  it('keeps a neutral pose available for Reduce Motion', () => {
    expect(NEUTRAL_POSE.bodyScale).toBe(1)
    expect(NEUTRAL_POSE.bodyRotationDeg).toBe(0)
    expect(NEUTRAL_POSE.eyeScaleX).toBe(1)
    expect(NEUTRAL_POSE.eyeScaleY).toBe(1)
    expect(NEUTRAL_POSE.eyeRotationDeg).toBe(0)
    expect(avatarMain).toContain('prefers-reduced-motion')
  })

  it('drives the life loop from the web surface without cursor tracking', () => {
    expect(avatarMain).toContain('idleLifePose')
    expect(avatarMain).not.toContain('mousemove')
    expect(avatarMain).not.toContain('pointermove')
  })

  it('applies uniform body scale so ears and tail cannot distort the circle', () => {
    expect(avatarStyles).toMatch(/--fatcat-body-scale/)
    expect(avatarStyles).not.toMatch(/scale\(\s*var\(--fatcat-body-scale[^,)]*\)\s*,/)
    expect(avatarStyles).toMatch(/--fatcat-eye-scale-x/)
    expect(avatarStyles).toMatch(/--fatcat-eye-scale-y/)
    expect(avatarStyles).toMatch(/--fatcat-ear-rotation/)
    expect(avatarStyles).toMatch(/--fatcat-tail-tip-rotation/)
  })
})
