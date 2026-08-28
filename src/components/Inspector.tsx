import type { AvatarDefinition } from '@bible-strong/avatar-core'

type InspectorProps = {
  definition: Readonly<AvatarDefinition>
  expression?: string
  animation?: string
}

function NumberPair({ label, left, right }: { label: string; left: number; right: number }) {
  return <div className="inspector-line"><span>{label}</span><code>{Math.round(left)} / {Math.round(right)}</code></div>
}

export function Inspector({ definition, expression, animation }: InspectorProps) {
  if (animation) {
    const item = definition.animations[animation]
    return (
      <section className="inspector" aria-labelledby="inspector-heading">
        <div className="inspector-heading"><p className="eyebrow">Timeline inspector</p><h2 id="inspector-heading">{item.metadata?.label ?? animation}</h2><code>{animation}</code></div>
        <p className="inspector-description">{item.metadata?.description ?? 'No description supplied for this animation.'}</p>
        <div className="inspector-pills"><span>{item.playbackMode}</span><span>{item.steps.length} expressions</span><span>{item.blink.enabled ? 'blink on' : 'blink off'}</span></div>
        <div className="step-list">
          {item.steps.map((step, index) => <div className="step-row" key={`${step.expression}-${index}`}><span className="step-index">{String(index + 1).padStart(2, '0')}</span><strong>{step.expression}</strong><span>{step.holdMs}ms hold<br />{step.transitionMs}ms {step.transition}</span></div>)}
        </div>
        {item.blink.enabled && <div className="blink-note"><span className="blink-mark" /> Blink window: {item.blink.minIntervalMs}–{item.blink.maxIntervalMs}ms interval · {item.blink.durationMs}ms duration</div>}
      </section>
    )
  }

  const key = expression ?? 'neutral'
  const item = definition.expressions[key]
  return (
    <section className="inspector" aria-labelledby="inspector-heading">
      <div className="inspector-heading"><p className="eyebrow">Expression inspector</p><h2 id="inspector-heading">{key}</h2><code>{item.motion.body} body · {item.motion.eyes} eyes</code></div>
      <p className="inspector-description">Direct pose with no timeline. The renderer uses this definition as-is.</p>
      <div className="inspector-grid">
        <div><span className="metric-label">Head rotation</span><div className="metric-value">{Math.round(item.head.x)}° <small>x</small> {Math.round(item.head.y)}° <small>y</small> {Math.round(item.head.z)}° <small>z</small></div></div>
        <div><span className="metric-label">Eye spacing</span><div className="metric-value">{Math.round(item.eyes.spacing)} <small>units</small></div></div>
        <div><span className="metric-label">Left eye</span><NumberPair label="w / h" left={item.eyes.left.width} right={item.eyes.left.height} /></div>
        <div><span className="metric-label">Right eye</span><NumberPair label="w / h" left={item.eyes.right.width} right={item.eyes.right.height} /></div>
      </div>
    </section>
  )
}
