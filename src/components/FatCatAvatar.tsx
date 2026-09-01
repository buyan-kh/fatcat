import { useEffect, useRef } from 'react'
import { Avatar, type AvatarController } from '@bible-strong/avatar-react'
import type { AnimationKey, AvatarDefinition } from '@bible-strong/avatar-core'
import { avatarAnimationForPetState, type PetState } from '../lib/pet-surface'
import { avatarAnimationForState, type FatCatPresenceState } from '../lib/fatcat-presence'

type FatCatAvatarProps = {
  definition: Readonly<AvatarDefinition>
  state: PetState | FatCatPresenceState
  paused?: boolean
  onPauseChange?: (paused: boolean) => void
}

export function FatCatAvatar({ definition, state, paused = false, onPauseChange }: FatCatAvatarProps) {
  const isPetState = (petState: PetState | FatCatPresenceState): petState is PetState =>
    (['idle', 'listening', 'understanding', 'planning', 'askingPermission', 'acting', 'verifying', 'celebrating', 'recovering', 'suspicious', 'sleeping'] as string[]).includes(petState)
  const animation = isPetState(state)
    ? avatarAnimationForPetState[state]
    : avatarAnimationForState[state as FatCatPresenceState].animation
  const controllerRef = useRef<AvatarController>(null)

  useEffect(() => {
    if (paused) controllerRef.current?.pause()
    else controllerRef.current?.play(animation as AnimationKey)
  }, [animation, paused])

  return (
    <div className="pet-avatar" data-fatcat-state={state}>
      <Avatar
        key={state + '-' + animation}
        definition={definition}
        ref={controllerRef}
        defaultAnimation={animation}
        size="184px"
        ariaLabel={'FatCat is ' + state}
      />
      {onPauseChange ? <button
        type="button"
        className="sr-only"
        aria-label={paused ? 'Resume FatCat animation' : 'Pause FatCat animation'}
        onClick={() => onPauseChange?.(!paused)}
      >
        {paused ? 'Resume' : 'Pause'}
      </button> : null}
    </div>
  )
}
