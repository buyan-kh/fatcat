import { useState } from 'react'
import { Brain } from '@phosphor-icons/react/Brain'
import { CaretDown } from '@phosphor-icons/react/CaretDown'
import { CheckCircle } from '@phosphor-icons/react/CheckCircle'
import { Code } from '@phosphor-icons/react/Code'
import { SpinnerGap } from '@phosphor-icons/react/SpinnerGap'
import { XCircle } from '@phosphor-icons/react/XCircle'
import type { TurnActivity as TurnActivityModel } from '@shared/chat'
import { cn } from '@renderer/lib/utils'

export function TurnActivity({ activities }: { activities: TurnActivityModel[] }) {
  const [open, setOpen] = useState<Set<string>>(new Set())
  if (activities.length === 0) return null

  const toggle = (id: string) => setOpen((current) => {
    const next = new Set(current)
    if (next.has(id)) next.delete(id)
    else next.add(id)
    return next
  })

  return (
    <div className="mb-3 space-y-0.5" aria-label="Hermes activity">
      {activities.map((activity) => {
        const expanded = open.has(activity.id)
        const expandable = Boolean(activity.steps?.length || Object.keys(activity.arguments ?? {}).length || activity.detail)
        return (
          <div key={activity.id} className="group/activity">
            <button
              type="button"
              aria-expanded={expandable ? expanded : undefined}
              aria-label={`${activity.label}, ${activity.status}`}
              disabled={!expandable}
              onClick={() => expandable && toggle(activity.id)}
              className="flex min-h-7 w-full min-w-0 items-center gap-2 rounded-md px-1.5 text-left text-xs text-muted-foreground transition-colors hover:bg-muted/70 disabled:cursor-default disabled:opacity-100"
            >
              <span className="flex size-4 shrink-0 items-center justify-center">
                {activity.kind === 'plan' ? <Brain className="size-3.5" /> : activity.kind === 'tool' ? <Code className="size-3.5" /> : statusIcon(activity.status)}
              </span>
              <span className="shrink-0 font-medium text-foreground/80">{activity.label}</span>
              {activity.kind === 'tool' && Object.entries(activity.arguments ?? {}).slice(0, 1).map(([key, value]) => (
                <span key={key} className="min-w-0 flex-1 truncate rounded bg-muted px-1.5 py-0.5 font-mono text-[10.5px]">{value}</span>
              ))}
              <span className="ml-auto shrink-0 capitalize">{activity.status}</span>
              {expandable && <CaretDown className={cn('size-3 shrink-0 transition-transform', expanded && 'rotate-180')} />}
            </button>
            {expandable && expanded && (
              <div className="ml-3 mt-0.5 space-y-1 border-l pl-4 text-[11px] leading-5 text-muted-foreground">
                {activity.steps?.map((step, index) => <p key={`${index}-${step}`}>{index + 1}. {step}</p>)}
                {Object.entries(activity.arguments ?? {}).map(([key, value]) => <p key={key}><span className="font-medium text-foreground/70">{key}</span> <code>{value}</code></p>)}
                {activity.detail && <p>{activity.detail}</p>}
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}

function statusIcon(status: TurnActivityModel['status']) {
  if (status === 'completed') return <CheckCircle className="size-3.5 text-emerald-500" weight="fill" />
  if (status === 'failed') return <XCircle className="size-3.5 text-destructive" weight="fill" />
  return <SpinnerGap className="size-3.5 animate-spin" />
}
