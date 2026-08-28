import { useRef, useState } from 'react'
import { Avatar, type AvatarController } from '@bible-strong/avatar-react'
import type { AvatarDefinition } from '@bible-strong/avatar-core'
import { avatarAnimationForState, type CompanionState } from '../lib/companion'

type PeppaCompanionAvatarProps = {
  definition: Readonly<AvatarDefinition>
  state: CompanionState
  paused: boolean
  onPauseChange: (paused: boolean) => void
}

export function PeppaCompanionAvatar({ definition, state, paused, onPauseChange }: PeppaCompanionAvatarProps) {
  const controller = useRef<AvatarController>(null)
  const [visibleExpression, setVisibleExpression] = useState('neutral')
  const mapping = avatarAnimationForState[state]

  function togglePause() {
    if (paused) controller.current?.play(mapping.animation)
    else controller.current?.pause()
    onPauseChange(!paused)
  }

  return (
    <div className="companion-avatar-wrap">
      <div className="companion-avatar-stage">
        <span className="avatar-orbit orbit-one" aria-hidden="true" />
        <span className="avatar-orbit orbit-two" aria-hidden="true" />
        <Avatar
          key={`${state}-${mapping.animation}`}
          ref={controller}
          definition={definition}
          defaultAnimation={mapping.animation}
          size="clamp(150px, 21vw, 236px)"
          ariaLabel={`Peppa is ${mapping.label}`}
          onExpressionChange={setVisibleExpression}
        />
        <div className="companion-avatar-tag"><span className="peppa-live-dot" /> {state.replaceAll('_', ' ')}</div>
      </div>
      <div className="companion-avatar-footer">
        <div><span className="eyebrow">Peppa is {mapping.label.toLowerCase()}</span><p>{paused ? 'Animation paused' : `Showing ${visibleExpression} as the timeline plays.`}</p></div>
        <button className="button button-secondary" type="button" onClick={togglePause}>{paused ? 'Resume Peppa' : 'Pause Peppa'}</button>
      </div>
    </div>
  )
}

