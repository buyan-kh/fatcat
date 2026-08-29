import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { FOLLOW_DELAY_MS, createDelayedSignal, flightTiltAt } from './fatcat-motion'

const avatarMain = readFileSync(fileURLToPath(new URL('../avatar-main.tsx', import.meta.url)), 'utf8')

describe('FatCat flight tilt playback', () => {
  it('ramps the tilt up and back down over the flight without exceeding the envelope', () => {
    const duration = 2600
    expect(flightTiltAt(0, duration, 8)).toBeCloseTo(0, 3)
    expect(flightTiltAt(duration, duration, 8)).toBeCloseTo(0, 3)
    expect(flightTiltAt(duration / 2, duration, 8)).toBeCloseTo(8, 3)
    for (let t = 0; t <= duration; t += 50) {
      expect(Math.abs(flightTiltAt(t, duration, 8))).toBeLessThanOrEqual(8)
    }
  })

  it('keeps the sign of the travel direction', () => {
    expect(flightTiltAt(1300, 2600, -8)).toBeCloseTo(-8, 3)
  })

  it('never tilts past the flight once it is over', () => {
    expect(flightTiltAt(9000, 2600, 8)).toBeCloseTo(0, 3)
  })
})

describe('FatCat delayed appendage signal', () => {
  it('replays the body signal after the configured delay', () => {
    const signal = createDelayedSignal()
    for (let t = 0; t <= 1000; t += 10) signal.push(t, t)
    expect(signal.sampleAt(500 - FOLLOW_DELAY_MS.ears)).toBeCloseTo(500 - FOLLOW_DELAY_MS.ears, 1)
    expect(signal.sampleAt(500)).toBeCloseTo(500, 1)
  })

  it('interpolates between samples instead of stepping', () => {
    const signal = createDelayedSignal()
    signal.push(0, 0)
    signal.push(100, 10)
    expect(signal.sampleAt(50)).toBeCloseTo(5, 3)
  })

  it('returns the oldest known value before history begins', () => {
    const signal = createDelayedSignal()
    signal.push(1000, 7)
    expect(signal.sampleAt(200)).toBe(7)
  })
})

describe('FatCat flight surface contract', () => {
  it('exposes a cancellable flight bridge next to setAnimation', () => {
    expect(avatarMain).toContain('setFlight')
    expect(avatarMain).toContain('data-flight')
  })

  it('exposes an event reaction bridge and uses neutral grounded motion', () => {
    expect(avatarMain).toContain('setReaction')
    expect(avatarMain).toContain('groundedLifePose')
    expect(avatarMain).not.toContain('pose = idleLifePose(elapsed)')
  })

  it('keeps window movement out of the web surface: the page only tilts and poses', () => {
    expect(avatarMain).not.toContain('window.moveTo')
    expect(avatarMain).not.toContain('window.moveBy')
  })
})
