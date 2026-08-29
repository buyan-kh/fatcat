import { useEffect, useRef, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { Avatar } from '@bible-strong/avatar-react'
import type { AnimationKey, AvatarDefinition } from '@bible-strong/avatar-core'
import bundledDefinition from '../public/strobi.avatar.json'
import {
  appendageScaleDelta,
  earFollowRotationDelta,
} from './lib/fatcat-attachment'
import {
  FOLLOW_DELAY_MS,
  NEUTRAL_FOLLOW,
  NEUTRAL_POSE,
  createDelayedSignal,
  earTwitchRotation,
  earTwitchSchedule,
  eventReactionPose,
  flightTiltAt,
  followThroughPose,
  groundedLifePose,
} from './lib/fatcat-motion'
import './avatar-styles.css'

const animationKeys = new Set(Object.keys(bundledDefinition.animations))

type FlightPhase = 'grounded' | 'preparing' | 'flying' | 'landing' | 'settling'

const flightPhases = new Set<FlightPhase>(['grounded', 'preparing', 'flying', 'landing', 'settling'])

type AvatarBridgeWindow = Window & {
  fatCatAvatar?: {
    setAnimation: (animation: string) => void
    setFlight: (phase: string, tiltDeg?: number, durationMs?: number) => void
    setReaction: (intensity?: number, durationMs?: number) => void
  }
}

function notifyNative(type: 'ready' | 'click' | 'context-menu') {
  const handler = (window as Window & {
    webkit?: { messageHandlers?: { fatcatAvatar?: { postMessage: (message: unknown) => void } } }
  }).webkit?.messageHandlers?.fatcatAvatar
  handler?.postMessage({ type })
}

const EAR_TWITCH_SEED = 0xfa7ca7
const earTwitches = earTwitchSchedule(EAR_TWITCH_SEED, 40)
const earTwitchWindowMs = earTwitches[earTwitches.length - 1] + 4000

const TAIL_TIP_FLIGHT_OVERSHOOT = 1.12

function FatCatAvatarSurface() {
  const [animation, setAnimation] = useState('idle')
  const [flightPhase, setFlightPhase] = useState<FlightPhase>('grounded')
  const safeAnimation = animationKeys.has(animation) ? animation : 'idle'
  const frameRef = useRef<HTMLDivElement | null>(null)
  const flightRef = useRef({
    phase: 'grounded' as FlightPhase,
    changedAt: Number.NEGATIVE_INFINITY,
    flyingStartedAt: Number.NEGATIVE_INFINITY,
    maxTiltDeg: 0,
    durationMs: 0,
  })
  const reactionRef = useRef({
    startedAt: Number.NEGATIVE_INFINITY,
    intensity: 0,
    durationMs: 0,
  })
  const tiltHistoryRef = useRef(createDelayedSignal())

  useEffect(() => {
    const bridgeWindow = window as AvatarBridgeWindow
    bridgeWindow.fatCatAvatar = {
      setAnimation,
      setFlight: (phase, tiltDeg = 0, durationMs = 0) => {
        if (!flightPhases.has(phase as FlightPhase)) return
        const flight = flightRef.current
        flight.phase = phase as FlightPhase
        flight.changedAt = performance.now()
        if (phase === 'flying') {
          flight.flyingStartedAt = flight.changedAt
          flight.maxTiltDeg = tiltDeg
          flight.durationMs = durationMs
        }
        setFlightPhase(phase as FlightPhase)
      },
      setReaction: (intensity = 1, durationMs = 650) => {
        if (!Number.isFinite(intensity) || !Number.isFinite(durationMs) || durationMs <= 0) return
        reactionRef.current = { startedAt: performance.now(), intensity, durationMs }
      },
    }
    notifyNative('ready')
    return () => {
      delete bridgeWindow.fatCatAvatar
    }
  }, [])

  useEffect(() => {
    const frame = frameRef.current
    if (!frame) return
    // Reduce Motion freezes the life loop to the neutral pose each frame.
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)')
    const isIdle = safeAnimation === 'idle'
    const origin = performance.now()
    let request = 0

    const apply = (now: number) => {
      const flight = flightRef.current
      const flightActive = flight.phase !== 'grounded'
      const elapsed = now - origin
      let pose = NEUTRAL_POSE
      let follow = NEUTRAL_FOLLOW
      let twitch = 0
      let earPerk = 0
      if (!reduceMotion.matches && isIdle && !flightActive) {
        pose = groundedLifePose(elapsed)
        follow = followThroughPose(elapsed)
        twitch = earTwitchRotation(elapsed % earTwitchWindowMs, earTwitches)
      }
      const reactionState = reactionRef.current
      const reactionElapsed = now - reactionState.startedAt
      const reaction = !reduceMotion.matches && reactionElapsed >= 0 && reactionElapsed < reactionState.durationMs
        ? eventReactionPose(reactionElapsed, reactionState.intensity)
        : { bodyScale: 1, earPerk: 0, eyeScaleY: 1 }
      let bodyScale = pose.bodyScale * reaction.bodyScale
      let eyeScaleY = pose.eyeScaleY * reaction.eyeScaleY
      let tailScale = follow.tailScale

      let tilt = 0
      if (!reduceMotion.matches && flightActive) {
        const sincePhase = now - flight.changedAt
        if (flight.phase === 'preparing') {
          const crouch = Math.min(1, sincePhase / 140)
          bodyScale *= 1 - 0.06 * crouch
          eyeScaleY *= 1 + 0.06 * crouch
          earPerk = Math.max(earPerk, 0.6 * crouch, reaction.earPerk)
          tailScale *= 1 - 0.08 * crouch
        }
        if (flight.phase === 'flying' || flight.phase === 'landing') {
          tilt = flightTiltAt(now - flight.flyingStartedAt, flight.durationMs, flight.maxTiltDeg)
        }
        if (flight.phase === 'settling') {
          const pulse = Math.sin(Math.min(1, sincePhase / 320) * Math.PI)
          bodyScale *= 1 + 0.04 * pulse
        }
      }
      const history = tiltHistoryRef.current
      history.push(now, tilt)
      const earFlightTilt = history.sampleAt(now - FOLLOW_DELAY_MS.ears)
      const tailBaseFlight = history.sampleAt(now - FOLLOW_DELAY_MS.tailBase)
      const tailMidFlight = history.sampleAt(now - FOLLOW_DELAY_MS.tailMid)
      const tailTipFlight = history.sampleAt(now - FOLLOW_DELAY_MS.tailTip) * TAIL_TIP_FLIGHT_OVERSHOOT

      earPerk = Math.max(earPerk, reaction.earPerk)
      const bodyRotationDeg = pose.bodyRotationDeg + tilt
      const earFollowDelta = earFollowRotationDelta(bodyRotationDeg, follow.earRotationDeg + earFlightTilt)
      const tailBaseDelta = earFollowRotationDelta(bodyRotationDeg, follow.tailBaseDeg + tailBaseFlight)
      const tailScaleDelta = appendageScaleDelta(bodyScale, tailScale)

      const style = frame.style
      style.setProperty('--fatcat-body-scale', bodyScale.toFixed(4))
      style.setProperty('--fatcat-body-rotation', `${bodyRotationDeg.toFixed(3)}deg`)
      style.setProperty('--fatcat-eye-scale-x', pose.eyeScaleX.toFixed(4))
      style.setProperty('--fatcat-eye-scale-y', eyeScaleY.toFixed(4))
      style.setProperty('--fatcat-eye-rotation', `${pose.eyeRotationDeg.toFixed(3)}deg`)
      style.setProperty('--fatcat-eye-offset-x', `${pose.eyeOffsetX.toFixed(3)}px`)
      style.setProperty('--fatcat-ear-follow-rotation', `${earFollowDelta.toFixed(3)}deg`)
      style.setProperty('--fatcat-ear-twitch', `${twitch.toFixed(3)}deg`)
      style.setProperty('--fatcat-ear-perk-rotation', `${(-5 * earPerk).toFixed(3)}deg`)
      style.setProperty('--fatcat-tail-base-rotation', `${tailBaseDelta.toFixed(3)}deg`)
      style.setProperty('--fatcat-tail-mid-rotation', `${(follow.tailMidDeg - follow.tailBaseDeg + tailMidFlight - tailBaseFlight).toFixed(3)}deg`)
      style.setProperty('--fatcat-tail-tip-rotation', `${(follow.tailTipDeg - follow.tailMidDeg + tailTipFlight - tailMidFlight).toFixed(3)}deg`)
      style.setProperty('--fatcat-tail-scale', tailScaleDelta.toFixed(4))
      request = requestAnimationFrame(apply)
    }

    request = requestAnimationFrame(apply)
    return () => cancelAnimationFrame(request)
  }, [safeAnimation])

  return (
    <main
      className="fatcat-avatar-surface"
      data-animation={safeAnimation}
      data-flight={flightPhase}
      aria-label="FatCat avatar"
      onClick={() => {
        notifyNative('click')
      }}
      onContextMenu={(event) => {
        event.preventDefault()
        notifyNative('context-menu')
      }}
    >
      <div className="fatcat-avatar-frame" ref={frameRef}>
        <svg className="fatcat-appendages" viewBox="-150 -150 300 300" aria-hidden="true">
          <g className="fatcat-tail-follow">
            <g className="fatcat-tail-drift">
              <path className="fatcat-tail" d="M96 53c28 12 42 34 30 55-8 14 2 25 17 19" />
              <path className="fatcat-tail-tip" d="M128 108c-8 14 2 25 15 19" />
            </g>
          </g>
          <g className="fatcat-ears">
            <g className="fatcat-ear-left">
              <path className="fatcat-ear" d="M-105-62-84-130q3-10 11-1l38 69Z" />
              <path className="fatcat-inner-ear" d="M-91-74-82-113-61-76Z" />
            </g>
            <g className="fatcat-ear-right">
              <path className="fatcat-ear" d="M105-62 84-130q-3-10-11-1l-38 69Z" />
              <path className="fatcat-inner-ear" d="M91-74 82-113 61-76Z" />
            </g>
          </g>
        </svg>
        <Avatar
          definition={bundledDefinition as Readonly<AvatarDefinition>}
          animation={safeAnimation as AnimationKey}
          size="100%"
          className="fatcat-avatar"
          ariaLabel="FatCat"
        />
      </div>
    </main>
  )
}

createRoot(document.getElementById('root')!).render(<FatCatAvatarSurface />)
