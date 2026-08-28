import type { AvatarDefinition } from '@bible-strong/avatar-core'
import { ImportAvatar } from './ImportAvatar'
import { summarizeDefinition, type DefinitionSummary } from '../lib/avatar-data'

type DefinitionTab = {
  id: string
  definition: Readonly<AvatarDefinition>
  imported: boolean
}

type DefinitionRailProps = {
  summary: DefinitionSummary
  tabs: DefinitionTab[]
  activeId: string
  onSelect: (id: string) => void
  onImport: (definition: Readonly<AvatarDefinition>) => void
  onError: (message: string) => void
  onRemove: (id: string) => void
  importError: string
}

export function DefinitionRail({ summary, tabs, activeId, onSelect, onImport, onError, onRemove, importError }: DefinitionRailProps) {
  return (
    <aside className="definition-rail" aria-label="Avatar definition controls">
      <div className="rail-section">
        <div className="section-kicker">Loaded definitions</div>
        <div className="definition-tabs" role="tablist" aria-label="Loaded avatar definitions">
          {tabs.map((tab) => {
            const tabSummary = summarizeDefinition(tab.definition)
            return (
              <div className="definition-tab-row" key={tab.id}>
                <button
                  className={`definition-tab ${activeId === tab.id ? 'is-active' : ''}`}
                  type="button"
                  role="tab"
                  aria-selected={activeId === tab.id}
                  onClick={() => onSelect(tab.id)}
                >
                  <span className="definition-avatar-mark" style={{ backgroundColor: tabSummary.bodyColor }} aria-hidden="true" />
                  <span>
                    <strong>{tabSummary.name}</strong>
                    <small>{tab.imported ? 'Imported' : 'Bundled'}</small>
                  </span>
                </button>
                {tab.imported && (
                  <button className="remove-tab" type="button" aria-label={`Remove ${tabSummary.name}`} onClick={() => onRemove(tab.id)}>
                    ×
                  </button>
                )}
              </div>
            )
          })}
        </div>
        <ImportAvatar onImport={onImport} onError={onError} />
        {importError && <p className="error-message" role="alert">{importError}</p>}
      </div>

      <div className="rail-section">
        <div className="section-kicker">Definition readout</div>
        <div className="readout-name">{summary.name}</div>
        <dl className="definition-stats">
          <div><dt>Body</dt><dd>{summary.bodyType}</dd></div>
          <div><dt>Size</dt><dd>{summary.dimensions}</dd></div>
          <div><dt>Expressions</dt><dd>{summary.expressionCount}</dd></div>
          <div><dt>Animations</dt><dd>{summary.animationCount}</dd></div>
        </dl>
      </div>

      <div className="rail-section color-readout">
        <div className="section-kicker">Palette</div>
        <div className="swatch-row"><span className="swatch" style={{ background: summary.bodyColor }} /><code>{summary.bodyColor}</code><span>body</span></div>
        <div className="swatch-row"><span className="swatch" style={{ background: summary.eyeColor }} /><code>{summary.eyeColor}</code><span>eyes</span></div>
      </div>
    </aside>
  )
}
