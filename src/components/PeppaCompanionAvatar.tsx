import { Avatar } from '@bible-strong/avatar-react'
import type { AvatarDefinition } from '@bible-strong/avatar-core'
import { avatarAnimationForPetState, type PetState } from '../lib/pet-surface'
import { avatarAnimationForState, type CompanionState } from '../lib/companion'

type PeppaCompanionAvatarProps = {
  definition: Readonly<AvatarDefinition>
  state: PetState | CompanionState
  paused?: boolean
  onPauseChange?: (paused: boolean) => void
}

export function PeppaCompanionAvatar({ definition, state }: PeppaCompanionAvatarProps) {
  const isPetState = (petState: PetState | CompanionState): petState is PetState =>
    (['idle', 'listening', 'understanding', 'planning', 'askingPermission', 'acting', 'verifying', 'celebrating', 'recovering', 'suspicious', 'sleeping'] as string[]).includes(petState)
  const animation = isPetState(state)
    ? avatarAnimationForPetState[state]
    : avatarAnimationForState[state as CompanionState].animation

  return (
    <div className="pet-avatar" data-peppa-state={state}>
      <Avatar
        key={state + '-' + animation}
        definition={definition}
        defaultAnimation={animation}
        size="184px"
        ariaLabel={'Peppa is ' + state}
      />
    </div>
  )
}
