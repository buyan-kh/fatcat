import { useEffect, useRef, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { Avatar } from '@bible-strong/avatar-react'
import type { AnimationKey, AvatarDefinition } from '@bible-strong/avatar-core'
import bundledDefinition from '../public/strobi.avatar.json'
import {
  CLICK_REACTION_DURATION_MS,
  NEUTRAL_FOLLOW,
  NEUTRAL_POSE,
  clickReactionPose,
  earTwitchRotation,
  earTwitchSchedule,
  followThroughPose,
  idleLifePose,
} from './lib/fatcat-motion'
import './avatar-styles.css'

const animationKeys = new Set(Object.keys(bundledDefinition.animations))

type AvatarBridgeWindow = Window & {
  fatCatAvatar?: {
    setAnimation: (animation: string) => void
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

function FatCatAvatarSurface() {
  const [animation, setAnimation] = useState('idle')
  const safeAnimation = animationKeys.has(animation) ? animation : 'idle'
  const frameRef = useRef<HTMLDivElement | null>(null)
  const clickedAtRef = useRef(Number.NEGATIVE_INFINITY)

  useEffect(() => {
    const bridgeWindow = window as AvatarBridgeWindow
    bridgeWindow.fatCatAvatar = { setAnimation }
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
      const elapsed = now - origin
      let pose = NEUTRAL_POSE
      let follow = NEUTRAL_FOLLOW
      let twitch = 0
      let earPerk = 0
      if (!reduceMotion.matches && isIdle) {
        pose = idleLifePose(elapsed)
        follow = followThroughPose(elapsed)
        twitch = earTwitchRotation(elapsed % earTwitchWindowMs, earTwitches)
      }
      let bodyScale = pose.bodyScale
      let eyeScaleY = pose.eyeScaleY
      const sinceClick = now - clickedAtRef.current
      if (!reduceMotion.matches && sinceClick >= 0 && sinceClick < CLICK_REACTION_DURATION_MS) {
        const reaction = clickReactionPose(sinceClick)
        bodyScale *= reaction.bodyScale
        eyeScaleY *= reaction.eyeScaleY
        earPerk = reaction.earPerk
      }
      const style = frame.style
      style.setProperty('--fatcat-body-scale', bodyScale.toFixed(4))
      style.setProperty('--fatcat-body-rotation', `${pose.bodyRotationDeg.toFixed(3)}deg`)
      style.setProperty('--fatcat-eye-scale-x', pose.eyeScaleX.toFixed(4))
      style.setProperty('--fatcat-eye-scale-y', eyeScaleY.toFixed(4))
      style.setProperty('--fatcat-eye-rotation', `${pose.eyeRotationDeg.toFixed(3)}deg`)
      style.setProperty('--fatcat-eye-offset-x', `${pose.eyeOffsetX.toFixed(3)}px`)
      style.setProperty('--fatcat-ear-rotation', `${follow.earRotationDeg.toFixed(3)}deg`)
      style.setProperty('--fatcat-ear-twitch', `${twitch.toFixed(3)}deg`)
      style.setProperty('--fatcat-ear-scale', follow.earScale.toFixed(4))
      style.setProperty('--fatcat-ear-perk', `${(-6 * earPerk).toFixed(3)}px`)
      style.setProperty('--fatcat-tail-base-rotation', `${follow.tailBaseDeg.toFixed(3)}deg`)
      style.setProperty('--fatcat-tail-mid-rotation', `${(follow.tailMidDeg - follow.tailBaseDeg).toFixed(3)}deg`)
      style.setProperty('--fatcat-tail-tip-rotation', `${(follow.tailTipDeg - follow.tailMidDeg).toFixed(3)}deg`)
      style.setProperty('--fatcat-tail-scale', follow.tailScale.toFixed(4))
      request = requestAnimationFrame(apply)
    }

    request = requestAnimationFrame(apply)
    return () => cancelAnimationFrame(request)
  }, [safeAnimation])

  return (
    <main
      className="fatcat-avatar-surface"
      data-animation={safeAnimation}
      aria-label="FatCat avatar"
      onClick={() => {
        clickedAtRef.current = performance.now()
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
          <g className="fatcat-ears-follow">
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
