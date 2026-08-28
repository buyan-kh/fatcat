import type { AvatarDefinition } from '@bible-strong/avatar-core'

type ExpressionGalleryProps = {
  definition: Readonly<AvatarDefinition>
  selected?: string
  onSelect: (expression: string) => void
}

export function ExpressionGallery({ definition, selected, onSelect }: ExpressionGalleryProps) {
  return (
    <section className="catalog-section" aria-labelledby="expressions-heading">
      <div className="catalog-heading">
        <div>
          <p className="eyebrow">Direct poses</p>
          <h2 id="expressions-heading">Expressions <span>{definition.expressionOrder.length}</span></h2>
        </div>
        <p>Click a face to inspect it without a timeline.</p>
      </div>
      <div className="expression-grid">
        {definition.expressionOrder.map((key) => {
          const item = definition.expressions[key]
          const tone = item.colors?.body ?? definition.colors.body
          return (
            <button className={`expression-card ${selected === key ? 'is-selected' : ''}`} key={key} type="button" aria-pressed={selected === key} onClick={() => onSelect(key)}>
              <span className="mini-avatar" style={{ backgroundColor: tone, transform: `rotate(${item.head.z / 8}deg)` }} aria-hidden="true">
                <span className="mini-eye" style={{ width: `${Math.max(5, item.eyes.left.width / 4)}px`, height: `${Math.max(8, item.eyes.left.height / 4)}px`, transform: `rotate(${item.eyes.left.angle}deg)` }} />
                <span className="mini-eye" style={{ width: `${Math.max(5, item.eyes.right.width / 4)}px`, height: `${Math.max(8, item.eyes.right.height / 4)}px`, transform: `rotate(${item.eyes.right.angle}deg)` }} />
              </span>
              <span className="catalog-key">{key}</span>
              <span className="catalog-meta">head {Math.round(item.head.x)}, {Math.round(item.head.y)}, {Math.round(item.head.z)}</span>
            </button>
          )
        })}
      </div>
    </section>
  )
}
