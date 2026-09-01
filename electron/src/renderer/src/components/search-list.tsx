import { useState, type ReactNode } from 'react'
import { MagnifyingGlass } from '@phosphor-icons/react/MagnifyingGlass'
import { X } from '@phosphor-icons/react/X'
import { cn } from '@renderer/lib/utils'

export type SearchItem = string

export type SearchListLabels = {
  placeholder: string
  ariaLabel: string
  emptyTitle: string
  emptyHint: string
}

const DEFAULT_LABELS: SearchListLabels = {
  placeholder: 'Search chats…',
  ariaLabel: 'Search chats',
  emptyTitle: 'No results found',
  emptyHint: 'Adjust your search to try again',
}

export type SearchListProps = {
  items?: SearchItem[]
  labels?: SearchListLabels
  onPick?: (item: SearchItem, index: number) => void
  matches?: (item: SearchItem, query: string, index: number) => boolean
  itemAriaLabel?: (item: SearchItem, index: number) => string
  className?: string
  footer?: ReactNode
}

export default function SearchList({ items = [], labels = DEFAULT_LABELS, onPick, matches, itemAriaLabel, className, footer }: SearchListProps) {
  const [query, setQuery] = useState('')
  const results = query
    ? items.flatMap((item, index) => (matches?.(item, query, index) ?? item.toLowerCase().includes(query.toLowerCase())) ? [{ item, index }] : [])
    : items.slice(0, 5).map((item, index) => ({ item, index }))
  const empty = query.length > 2 && results.length === 0

  return (
    <div className={cn('flex min-h-[248px] w-full max-w-72 flex-col items-stretch', className)}>
      <div className="w-full self-start overflow-hidden rounded-[10px] border-[0.5px] border-border/70 bg-card shadow-md">
        <div className="flex h-9 items-center gap-2 border-b-[0.5px] border-border/70 px-3 transition-colors duration-100 hover:bg-accent/50">
          <MagnifyingGlass className="shrink-0 text-muted-foreground" size={14} />
          <input
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder={labels.placeholder}
            aria-label={labels.ariaLabel}
            className="nav-control min-w-0 flex-1 bg-transparent text-[13px] text-foreground outline-none placeholder:text-muted-foreground"
          />
          {query && <button aria-label="Clear search" type="button" onClick={() => setQuery('')} className="flex size-6 items-center justify-center rounded-full text-muted-foreground transition-colors duration-100 hover:bg-accent hover:text-foreground"><X size={11} /></button>}
        </div>

        {empty ? (
          <div className="flex flex-col items-center justify-center gap-1 px-4 py-8" style={{ animation: 'fatcat-fade-in 250ms ease-out both' }}>
            <span className="mb-1.5 flex size-8 items-center justify-center rounded-[8px] bg-muted text-muted-foreground shadow-sm"><MagnifyingGlass size={15} /></span>
            <span className="text-[13px] font-medium text-foreground">{labels.emptyTitle}</span>
            <span className="text-[12px] text-muted-foreground">{labels.emptyHint}</span>
          </div>
        ) : (
          <div className="p-1">
            <div className="flex flex-col gap-px">
              {results.map(({ item, index }, displayIndex) => <button key={`${item}-${index}`} data-menu-row aria-label={itemAriaLabel?.(item, index) ?? item} type="button" onClick={() => { setQuery(item); onPick?.(item, index) }} className="relative z-10 flex h-8 w-full items-center rounded-[6px] px-2 text-left text-[13px] text-foreground transition-colors hover:bg-accent" style={{ animation: `fatcat-fade-in 200ms ease-out ${displayIndex * 20}ms both` }}>{item}</button>)}
            </div>
          </div>
        )}
      </div>
      {footer}
    </div>
  )
}
