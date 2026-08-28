import type { AvatarDefinition } from '@bible-strong/avatar-core'

type AnimationGalleryProps = {
  definition: Readonly<AvatarDefinition>
  selected?: string
  onSelect: (animation: string) => void
}

export function AnimationGallery({ definition, selected, onSelect }: AnimationGalleryProps) {
  return (
    <section className="catalog-section" aria-labelledby="animations-heading">
      <div className="catalog-heading">
        <div>
          <p className="eyebrow">Playable timelines</p>
          <h2 id="animations-heading">Animations <span>{definition.animationOrder.length}</span></h2>
        </div>
        <p>Each row is an explicit sequence from the definition.</p>
      </div>
      <div className="animation-list">
        {definition.animationOrder.map((key) => {
          const item = definition.animations[key]
          const label = item.metadata?.label ?? key
          return (
            <button className={`animation-row ${selected === key ? 'is-selected' : ''}`} key={key} type="button" aria-pressed={selected === key} onClick={() => onSelect(key)}>
              <span className="timeline-icon" aria-hidden="true"><i /><i /><i /></span>
              <span className="animation-copy"><strong>{label}</strong><small>{key} · {item.metadata?.group ?? 'Unsorted'}</small></span>
              <span className="animation-stats"><b>{item.steps.length}</b> steps<br /><small>{item.playbackMode}</small></span>
              <span className="row-arrow" aria-hidden="true">↗</span>
            </button>
          )
        })}
      </div>
    </section>
  )
}
