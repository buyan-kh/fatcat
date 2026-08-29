import { useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { Avatar } from '@bible-strong/avatar-react'
import type { AnimationKey, AvatarDefinition } from '@bible-strong/avatar-core'
import bundledDefinition from '../public/strobi.avatar.json'
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

function FatCatAvatarSurface() {
  const [animation, setAnimation] = useState('idle')
  const safeAnimation = animationKeys.has(animation) ? animation : 'idle'

  useEffect(() => {
    const bridgeWindow = window as AvatarBridgeWindow
    bridgeWindow.fatCatAvatar = { setAnimation }
    notifyNative('ready')
    return () => {
      delete bridgeWindow.fatCatAvatar
    }
  }, [])

  return (
    <main
      className="fatcat-avatar-surface"
      data-animation={safeAnimation}
      aria-label="FatCat avatar"
      onClick={() => notifyNative('click')}
      onContextMenu={(event) => {
        event.preventDefault()
        notifyNative('context-menu')
      }}
    >
      <div className="fatcat-avatar-frame">
        <svg className="fatcat-appendages" viewBox="-150 -150 300 300" aria-hidden="true">
          <g className="fatcat-ears">
            <path className="fatcat-ear" d="M-105-62-84-130q3-10 11-1l38 69Z" />
            <path className="fatcat-ear" d="M105-62 84-130q-3-10-11-1l-38 69Z" />
            <path className="fatcat-inner-ear" d="M-91-74-82-113-61-76Z" />
            <path className="fatcat-inner-ear" d="M91-74 82-113 61-76Z" />
          </g>
          <path className="fatcat-tail" d="M96 53c28 12 42 34 30 55-8 14 2 25 17 19" />
          <path className="fatcat-tail-tip" d="M128 108c-8 14 2 25 15 19" />
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
