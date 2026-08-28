import { useRef, useState } from 'react'
import { Avatar, type AvatarController } from '@bible-strong/avatar-react'
import type { AvatarDefinition } from '@bible-strong/avatar-core'

type AvatarPreviewProps = {
  definition: Readonly<AvatarDefinition>
  expression?: string
  animation?: string
}

export function AvatarPreview({ definition, expression, animation }: AvatarPreviewProps) {
  const controller = useRef<AvatarController>(null)
  const [paused, setPaused] = useState(false)
  const [visibleExpression, setVisibleExpression] = useState(expression ?? 'neutral')
  const targetLabel = animation ? `animation / ${animation}` : `expression / ${expression ?? 'neutral'}`

  function pause() {
    controller.current?.pause()
    setPaused(true)
  }

  function resume() {
    if (animation) controller.current?.play(animation)
    setPaused(false)
  }

  function replay() {
    if (animation) {
      controller.current?.stop()
      controller.current?.play(animation)
      setPaused(false)
    }
  }

  return (
    <section className="preview-panel" aria-labelledby="preview-heading">
      <div className="panel-heading">
        <div>
          <p className="eyebrow">Live preview</p>
          <h2 id="preview-heading">{definition.name ?? 'Unnamed avatar'}</h2>
        </div>
        <span className="status-dot" aria-label="Renderer ready" title="Renderer ready" />
      </div>

      <div className="avatar-stage">
        <div className="stage-grid" aria-hidden="true" />
        <Avatar
          key={`${definition.name}-${targetLabel}`}
          ref={controller}
          definition={definition}
          defaultAnimation={animation}
          defaultExpression={expression}
          size="min(54vw, 330px)"
          ariaLabel={`${definition.name ?? 'Avatar'} showing ${targetLabel}`}
          onExpressionChange={setVisibleExpression}
        />
        <div className="stage-caption">
          <span>{targetLabel}</span>
          <span>{animation ? (paused ? 'paused' : 'playing') : visibleExpression}</span>
        </div>
      </div>

      <div className="preview-controls" aria-label="Playback controls">
        <button className="button button-secondary" type="button" onClick={paused ? resume : pause} disabled={!animation}>
          {paused ? 'Resume' : 'Pause'}
        </button>
        <button className="button button-quiet" type="button" onClick={replay} disabled={!animation}>
          Replay timeline
        </button>
        <span className="control-hint">{animation ? 'Inspect timing one loop at a time.' : 'Choose an animation to inspect playback.'}</span>
      </div>
    </section>
  )
}
