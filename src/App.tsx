import { useEffect, useState } from 'react'
import type { AvatarDefinition } from '@bible-strong/avatar-core'
import bundledDefinition from '../public/fatcat.avatar.json'
import { FatCatAvatar } from './components/FatCatAvatar'
import { petStates, type PetState } from './lib/pet-surface'

type NativeBridge = {
  petEvent?: (type: string) => void
  isAvailable?: () => boolean
}

function nativeBridge(): NativeBridge | undefined {
  if (typeof window === 'undefined') return undefined
  return (window as Window & { __FATCAT_NATIVE__?: NativeBridge }).__FATCAT_NATIVE__
}

export function App() {
  const [state, setState] = useState<PetState>('idle')

  useEffect(() => {
    function receiveState(event: Event) {
      const next = (event as CustomEvent<{ state?: string }>).detail?.state
      if (next && petStates.includes(next as PetState)) setState(next as PetState)
    }
    window.addEventListener('fatcat:state', receiveState)
    return () => window.removeEventListener('fatcat:state', receiveState)
  }, [])

  const emit = (type: string) => nativeBridge()?.petEvent?.(type)

  return (
    <main
      className="pet-surface"
      onClick={() => emit('pet-click')}
      onContextMenu={(event) => {
        event.preventDefault()
        emit('pet-context-menu')
      }}
      aria-label="FatCat desktop pet"
    >
      <FatCatAvatar
        definition={bundledDefinition as Readonly<AvatarDefinition>}
        state={state}
      />
    </main>
  )
}
