import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { Check } from '@phosphor-icons/react/Check'
import { CaretDown } from '@phosphor-icons/react/CaretDown'
import { Code } from '@phosphor-icons/react/Code'
import { SpinnerGap } from '@phosphor-icons/react/SpinnerGap'
import { Sparkle } from '@phosphor-icons/react/Sparkle'
import { X } from '@phosphor-icons/react/X'
import type { TurnActivity as TurnActivityModel, TurnState } from '@shared/chat'
import { cn } from '@renderer/lib/utils'

type TraceRow = {
  id: string
  primary: string
  secondary?: string
  arguments?: Record<string, string>
  detail?: string
  status: TurnState
  kind: TurnActivityModel['kind']
  expandable: boolean
}

const ACTIVE_STATES: TurnState[] = ['sending', 'thinking', 'working', 'streaming', 'stopping']

/** The supplied ThinkingState treatment, fed by real Hermes activities. */
export function TurnActivity({ activities }: { activities: TurnActivityModel[] }) {
  const [manualExpanded, setManualExpanded] = useState<boolean | null>(null)
  const [open, setOpen] = useState<Set<string>>(new Set())
  const traceRef = useRef<HTMLDivElement>(null)
  const [lineHeight, setLineHeight] = useState(0)
  const rows = toRows(activities)
  const working = activities.some((activity) => ACTIVE_STATES.includes(activity.status))
  const toolCount = activities.filter((activity) => activity.kind === 'tool').length
  const summary = working
    ? toolCount > 0 ? 'Running tools' : 'Thinking'
    : toolCount > 0 ? `${toolCount} tool call${toolCount === 1 ? '' : 's'}` : 'Thought for a moment'
  const expanded = manualExpanded ?? working

  useLayoutEffect(() => {
    if (traceRef.current) setLineHeight(traceRef.current.offsetHeight)
  }, [rows.length, expanded])

  useEffect(() => {
    if (working) return
    setManualExpanded(null)
  }, [working])

  if (activities.length === 0) return null

  const toggleActivity = (id: string) => setOpen((current) => {
    const next = new Set(current)
    if (next.has(id)) next.delete(id)
    else next.add(id)
    return next
  })

  return (
    <div
      className="thinking-state mb-3 flex w-full max-w-[38rem] flex-col"
      aria-label="Hermes activity"
      style={{ minHeight: working || expanded ? 176 : undefined, transition: 'min-height 400ms cubic-bezier(0.23,1,0.32,1)' }}
    >
      <button
        type="button"
        aria-expanded={expanded}
        aria-label={summary}
        onClick={() => setManualExpanded((current) => !(current ?? working))}
        className="thinking-state-trigger -mx-1.5 flex w-fit items-center gap-2 rounded-[8px] px-1.5 py-1 text-left transition-colors duration-100 hover:bg-muted/70"
      >
        <Sparkle className={cn('size-4', working ? 'text-muted-foreground' : 'text-muted-foreground/65')} weight={working ? 'fill' : 'regular'} />
        {working ? <span className="thinking-shimmer text-[13px] font-medium whitespace-nowrap">{summary}</span> : <span className="thinking-settled text-[13px] font-medium whitespace-nowrap text-muted-foreground">{summary}</span>}
        <CaretDown className={cn('size-3.5 text-muted-foreground/70 transition-transform duration-300', expanded && 'rotate-180')} />
      </button>

      <div
        className="grid transition-[grid-template-rows,opacity] duration-400"
        style={{ gridTemplateRows: expanded ? '1fr' : '0fr', opacity: expanded ? 1 : 0, transitionTimingFunction: 'cubic-bezier(0.23,1,0.32,1)' }}
      >
        <div className="min-h-0 overflow-hidden">
          <div className="relative ml-[5px] mt-1 pl-4">
            {rows.length > 0 && <span aria-hidden className="absolute left-[3px] top-[-8px] w-px bg-border/70" style={{ height: lineHeight ? lineHeight - 2 : 0, transition: 'height 500ms cubic-bezier(0.23,1,0.32,1)' }} />}
            <div ref={traceRef} className="flex flex-col gap-1 py-1">
              {rows.map((row, index) => {
                const content = (
                  <>
                    <span className="flex size-3.5 shrink-0 items-center justify-center">
                      {row.kind === 'tool' ? <Code className="size-3.5 text-muted-foreground" /> : row.status === 'failed' ? <X className="size-3.5 text-destructive" /> : row.status === 'completed' ? <Check className="size-3.5 text-emerald-500" /> : <SpinnerGap className="size-3.5 animate-spin text-muted-foreground" />}
                    </span>
                    <span className="min-w-0 truncate text-[12.5px] font-medium text-foreground/85">{row.primary}</span>
                    {row.secondary && (row.kind === 'tool' ? <code className="min-w-0 truncate rounded-[6px] bg-muted/65 px-1.5 py-0.5 font-mono text-[11px] text-muted-foreground">{row.secondary}</code> : <span className="min-w-0 truncate text-[11px] text-muted-foreground">{row.secondary}</span>)}
                  </>
                )
                const rowClass = 'flex min-h-7 w-full min-w-0 items-center gap-2 rounded-[6px] px-1.5 py-0.5 text-left transition-colors hover:bg-muted/60'
                const animation = { animation: `fade-up 320ms cubic-bezier(0.23,1,0.32,1) ${index * 120}ms both` }
                if (!row.expandable) return <div key={`${row.id}-${index}`} className={rowClass} style={animation}>{content}</div>
                const rowExpanded = open.has(row.id)
                return (
                  <div key={`${row.id}-${index}`}>
                    <button type="button" aria-expanded={rowExpanded} aria-label={`${row.primary}, ${row.status}`} onClick={() => toggleActivity(row.id)} className={rowClass} style={animation}>
                      {content}
                      <CaretDown className={cn('ml-auto size-3 shrink-0 text-muted-foreground/70 opacity-0 transition-[opacity,transform]', rowExpanded && 'rotate-180 opacity-100', 'group-hover:opacity-100')} />
                    </button>
                    {rowExpanded && (row.detail || row.arguments) && <div className="ml-6 mt-0.5 space-y-0.5 border-l border-border/70 pl-3 text-[11px] leading-5 text-muted-foreground">{row.arguments && Object.entries(row.arguments).map(([key, value]) => <p key={key}><span className="font-medium text-foreground/70">{key}</span> <code>{value}</code></p>)}{row.detail && <p>{row.detail}</p>}</div>}
                  </div>
                )
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

function toRows(activities: TurnActivityModel[]): TraceRow[] {
  const rows: TraceRow[] = []
  for (const activity of activities) {
    if (activity.kind === 'state') continue
    if (activity.kind === 'plan' && activity.steps?.length) {
      rows.push(...activity.steps.map((step, index): TraceRow => ({ id: `${activity.id}-${index}`, primary: step, status: activity.status, kind: activity.kind, expandable: false })))
      continue
    }
    const secondary = activity.kind === 'tool' ? Object.values(activity.arguments ?? {})[0] : undefined
    rows.push({ id: activity.id, primary: activity.label, secondary, arguments: activity.arguments, detail: activity.detail, status: activity.status, kind: activity.kind, expandable: Boolean(activity.detail || Object.keys(activity.arguments ?? {}).length) })
  }
  return rows
}
