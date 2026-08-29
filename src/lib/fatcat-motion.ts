export type IdleLifePose = {
  bodyScale: number
  bodyRotationDeg: number
  eyeScaleX: number
  eyeScaleY: number
  eyeRotationDeg: number
  eyeOffsetX: number
}

export type FollowThroughPose = {
  earRotationDeg: number
  earScale: number
  tailBaseDeg: number
  tailMidDeg: number
  tailTipDeg: number
  tailScale: number
}

export type ClickReactionPose = {
  bodyScale: number
  earPerk: number
  eyeScaleY: number
}

export const IDLE_LIFE_DURATION_MS = 2800

export const FOLLOW_DELAY_MS = {
  ears: 80,
  tailBase: 60,
  tailMid: 110,
  tailTip: 170,
} as const

const TAIL_TIP_OVERSHOOT = 1.15

export const NEUTRAL_POSE: IdleLifePose = {
  bodyScale: 1,
  bodyRotationDeg: 0,
  eyeScaleX: 1,
  eyeScaleY: 1,
  eyeRotationDeg: 0,
  eyeOffsetX: 0,
}

export const NEUTRAL_FOLLOW: FollowThroughPose = {
  earRotationDeg: 0,
  earScale: 1,
  tailBaseDeg: 0,
  tailMidDeg: 0,
  tailTipDeg: 0,
  tailScale: 1,
}

type Keyframe = readonly [timeMs: number, value: number]

function easeInOutCubic(t: number): number {
  return t * t * (3 - 2 * t)
}

function track(keyframes: readonly Keyframe[], tMs: number): number {
  const t = ((tMs % IDLE_LIFE_DURATION_MS) + IDLE_LIFE_DURATION_MS) % IDLE_LIFE_DURATION_MS
  if (t <= keyframes[0][0]) return keyframes[0][1]
  for (let i = 1; i < keyframes.length; i += 1) {
    const [time, value] = keyframes[i]
    const [previousTime, previousValue] = keyframes[i - 1]
    if (t <= time) {
      const progress = easeInOutCubic((t - previousTime) / (time - previousTime))
      return previousValue + (value - previousValue) * progress
    }
  }
  return keyframes[keyframes.length - 1][1]
}

/*
 * The nine idle phases, laid onto one seamless loop:
 * anticipatory crouch (0-300ms), quick expansion (300-560ms),
 * eyes enlarge (peaking with the expansion), lean left (900ms),
 * sweep through the right diagonal (1500ms), return upright (1900ms),
 * body settle (950ms), then a calm hold until the loop restarts.
 */
const BODY_SCALE: readonly Keyframe[] = [[0, 1], [300, 0.75], [560, 1.08], [950, 1]]
const BODY_ROTATION: readonly Keyframe[] = [[0, 0], [560, 0], [900, -8], [1500, 8], [1900, 0]]
const EYE_SCALE_Y: readonly Keyframe[] = [[0, 1], [300, 0.75], [560, 1.15], [1000, 1.05], [1400, 1]]
const EYE_SCALE_X: readonly Keyframe[] = [[0, 1], [300, 0.9], [560, 1.05], [1000, 1]]
const EYE_ROTATION: readonly Keyframe[] = [[0, 0], [560, 0], [900, -20], [1500, 20], [1900, 0]]
const EYE_OFFSET_X: readonly Keyframe[] = [[0, 0], [560, 0], [900, -9], [1500, 9], [1900, 0]]

export function idleLifePose(tMs: number): IdleLifePose {
  return {
    bodyScale: track(BODY_SCALE, tMs),
    bodyRotationDeg: track(BODY_ROTATION, tMs),
    eyeScaleX: track(EYE_SCALE_X, tMs),
    eyeScaleY: track(EYE_SCALE_Y, tMs),
    eyeRotationDeg: track(EYE_ROTATION, tMs),
    eyeOffsetX: track(EYE_OFFSET_X, tMs),
  }
}

export function groundedLifePose(tMs: number): IdleLifePose {
  return {
    bodyScale: 1,
    bodyRotationDeg: 0,
    eyeScaleX: 1,
    eyeScaleY: 1,
    eyeRotationDeg: track(EYE_ROTATION, tMs),
    eyeOffsetX: track(EYE_OFFSET_X, tMs),
  }
}

export function followThroughPose(tMs: number): FollowThroughPose {
  return {
    earRotationDeg: track(BODY_ROTATION, tMs - FOLLOW_DELAY_MS.ears),
    earScale: track(BODY_SCALE, tMs - FOLLOW_DELAY_MS.ears),
    tailBaseDeg: track(BODY_ROTATION, tMs - FOLLOW_DELAY_MS.tailBase),
    tailMidDeg: track(BODY_ROTATION, tMs - FOLLOW_DELAY_MS.tailMid),
    tailTipDeg: track(BODY_ROTATION, tMs - FOLLOW_DELAY_MS.tailTip) * TAIL_TIP_OVERSHOOT,
    tailScale: track(BODY_SCALE, tMs - FOLLOW_DELAY_MS.tailBase),
  }
}

export function createSeededRandom(seed: number): () => number {
  let state = seed >>> 0
  return () => {
    state = (state + 0x6d2b79f5) >>> 0
    let mixed = state
    mixed = Math.imul(mixed ^ (mixed >>> 15), mixed | 1)
    mixed ^= mixed + Math.imul(mixed ^ (mixed >>> 7), mixed | 61)
    return ((mixed ^ (mixed >>> 14)) >>> 0) / 4294967296
  }
}

export function earTwitchSchedule(seed: number, count: number): number[] {
  const random = createSeededRandom(seed)
  const times: number[] = []
  let cursor = 4000 + random() * 8000
  for (let i = 0; i < count; i += 1) {
    times.push(cursor)
    cursor += 4000 + random() * 8000
  }
  return times
}

export const EAR_TWITCH_DURATION_MS = 240

export function earTwitchRotation(tMs: number, schedule: readonly number[]): number {
  for (const start of schedule) {
    if (tMs >= start && tMs <= start + EAR_TWITCH_DURATION_MS) {
      return Math.sin(((tMs - start) / EAR_TWITCH_DURATION_MS) * Math.PI) * 3
    }
    if (start > tMs) break
  }
  return 0
}

export function flightTiltAt(elapsedMs: number, durationMs: number, maxTiltDeg: number): number {
  if (durationMs <= 0) return 0
  const progress = Math.min(1, Math.max(0, elapsedMs / durationMs))
  if (progress >= 1) return 0
  return maxTiltDeg * Math.sin(progress * Math.PI)
}

export type DelayedSignal = {
  push: (tMs: number, value: number) => void
  sampleAt: (tMs: number) => number
}

/*
 * Short rolling history of a live signal (such as the flight tilt) so ears and
 * tail can replay it slightly in the past for follow-through.
 */
export function createDelayedSignal(historyMs = 1000): DelayedSignal {
  const times: number[] = []
  const values: number[] = []
  return {
    push(tMs, value) {
      times.push(tMs)
      values.push(value)
      while (times.length > 1 && times[0] < tMs - historyMs) {
        times.shift()
        values.shift()
      }
    },
    sampleAt(tMs) {
      if (times.length === 0) return 0
      if (tMs <= times[0]) return values[0]
      for (let i = 1; i < times.length; i += 1) {
        if (tMs <= times[i]) {
          const span = times[i] - times[i - 1]
          const mix = span <= 0 ? 1 : (tMs - times[i - 1]) / span
          return values[i - 1] + (values[i] - values[i - 1]) * mix
        }
      }
      return values[values.length - 1]
    },
  }
}

export const CLICK_REACTION_DURATION_MS = 450
export const EVENT_REACTION_DURATION_MS = 650

export function eventReactionPose(sinceEventMs: number, intensity = 1): ClickReactionPose {
  const progress = Math.min(1, Math.max(0, sinceEventMs / EVENT_REACTION_DURATION_MS))
  const pulse = Math.sin(progress * Math.PI) * Math.min(1, Math.max(0, intensity))
  return {
    bodyScale: 1 + pulse * 0.05,
    earPerk: pulse,
    eyeScaleY: 1 + pulse * 0.08,
  }
}

export function clickReactionPose(sinceClickMs: number): ClickReactionPose {
  const progress = Math.min(1, Math.max(0, sinceClickMs / CLICK_REACTION_DURATION_MS))
  const pulse = Math.sin(progress * Math.PI)
  return {
    bodyScale: 1 + pulse * 0.04,
    earPerk: pulse,
    eyeScaleY: 1 + pulse * 0.08,
  }
}
