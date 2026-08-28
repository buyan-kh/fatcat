import { useEffect, useMemo, useState } from 'react'
import type { AvatarDefinition } from '@bible-strong/avatar-core'
import bundledDefinition from '../public/strobi.avatar.json'
import { AnimationGallery } from './components/AnimationGallery'
import { AvatarPreview } from './components/AvatarPreview'
import { CompanionDashboard } from './components/CompanionDashboard'
import { DefinitionRail } from './components/DefinitionRail'
import { ExpressionGallery } from './components/ExpressionGallery'
import { Inspector } from './components/Inspector'
import { normalizeImportedDefinition, summarizeDefinition } from './lib/avatar-data'
import { readNotes, writeNotes } from './lib/storage'

type LoadedDefinition = {
  id: string
  definition: Readonly<AvatarDefinition>
  imported: boolean
}

const bundledResult = normalizeImportedDefinition(JSON.stringify(bundledDefinition))
if (!bundledResult.ok) throw new Error(bundledResult.message)

const bundled: LoadedDefinition = { id: 'peppa', definition: bundledResult.definition, imported: false }

export function App() {
  const [definitions, setDefinitions] = useState<LoadedDefinition[]>([bundled])
  const [activeId, setActiveId] = useState(bundled.id)
  const [selectedExpression, setSelectedExpression] = useState<string | undefined>('neutral')
  const [selectedAnimation, setSelectedAnimation] = useState<string>()
  const [importError, setImportError] = useState('')
  const [notes, setNotes] = useState(() => (typeof window === 'undefined' ? '' : readNotes(window.localStorage)))
  const active = definitions.find((item) => item.id === activeId) ?? bundled
  const summary = useMemo(() => summarizeDefinition(active.definition), [active.definition])

  useEffect(() => {
    if (typeof window !== 'undefined') writeNotes(window.localStorage, notes)
  }, [notes])

  function selectDefinition(id: string) {
    const next = definitions.find((item) => item.id === id)
    if (!next) return
    setActiveId(id)
    setSelectedExpression(next.definition.expressionOrder[0] ?? 'neutral')
    setSelectedAnimation(undefined)
  }

  function selectExpression(expression: string) {
    setSelectedExpression(expression)
    setSelectedAnimation(undefined)
  }

  function selectAnimation(animation: string) {
    setSelectedAnimation(animation)
    setSelectedExpression(undefined)
  }

  function importDefinition(definition: Readonly<AvatarDefinition>) {
    const base = (definition.name?.trim() || 'Imported avatar').toLowerCase().replace(/[^a-z0-9]+/g, '-') || 'avatar'
    const id = `${base}-${Date.now()}`
    setDefinitions((current) => [...current, { id, definition, imported: true }])
    setActiveId(id)
    setSelectedExpression(definition.expressionOrder[0] ?? 'neutral')
    setSelectedAnimation(undefined)
  }

  function removeDefinition(id: string) {
    setDefinitions((current) => current.filter((item) => item.id !== id))
    if (activeId === id) selectDefinition('peppa')
  }

  return (
    <main className="app-shell">
      <header className="topbar">
        <a className="brand" href="/" aria-label="Peppa Anywhere home"><span className="brand-mark">P</span><span>Peppa Anywhere <em>/</em> local companion</span></a>
        <div className="topbar-meta"><span className="live-indicator" /> local-only MVP <span className="meta-divider" /> v0.1</div>
      </header>

      <CompanionDashboard definition={bundled.definition} />

      <section id="avatar-lab" className="avatar-lab" aria-label="Avatar workbench">
        <div className="intro lab-intro">
          <div>
            <p className="eyebrow">Preserved renderer workbench</p>
            <h1>Put every expression<br /><i>under the microscope.</i></h1>
          </div>
          <p className="intro-copy">The original Peppa playground remains here: every face and timeline is still loaded from the real avatar definition.</p>
        </div>

        <div className="workbench-layout">
        <AvatarPreview definition={active.definition} expression={selectedExpression} animation={selectedAnimation} />
        <DefinitionRail
          summary={summary}
          tabs={definitions}
          activeId={activeId}
          onSelect={selectDefinition}
          onImport={importDefinition}
          onError={setImportError}
          onRemove={removeDefinition}
          importError={importError}
        />
        </div>

        <Inspector definition={active.definition} expression={selectedExpression} animation={selectedAnimation} />
        <ExpressionGallery definition={active.definition} selected={selectedExpression} onSelect={selectExpression} />
        <AnimationGallery definition={active.definition} selected={selectedAnimation} onSelect={selectAnimation} />

        <section className="notes-section" aria-labelledby="notes-heading">
          <div><p className="eyebrow">Your lab notebook</p><h2 id="notes-heading">Keep the good discoveries.</h2><p>Notes stay in this browser only. Capture which states feel useful before we bring them into a product.</p></div>
          <label className="notes-field"><span className="visually-hidden">Experiment notes</span><textarea value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="e.g. joyful-wide feels like a good completion state…" /></label>
        </section>
      </section>

      <footer className="footer"><span>Peppa Anywhere · local companion MVP.</span><span>{summary.name} is loaded from a local definition.</span></footer>
    </main>
  )
}
