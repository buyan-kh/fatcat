import type { ReactNode } from 'react'
import { Minus } from '@phosphor-icons/react/Minus'
import { Square } from '@phosphor-icons/react/Square'
import { X } from '@phosphor-icons/react/X'
import { cn } from '@renderer/lib/utils'

type WindowControlsProps = {
  isMaximized: boolean
  onMinimize: () => void
  onToggleMaximize: () => void
  onClose: () => void
}

export function WindowControls({ isMaximized, onMinimize, onToggleMaximize, onClose }: WindowControlsProps) {
  return (
    <div className="app-no-drag flex h-9 shrink-0 items-center gap-0.5 rounded-[10px] border-[0.5px] border-border/70 bg-card/80 p-0.5 shadow-sm" aria-label="Window controls">
      <WindowButton label="Minimize window" onClick={onMinimize}>
        <Minus size={14} />
      </WindowButton>
      <WindowButton label={isMaximized ? 'Restore window' : 'Maximize window'} onClick={onToggleMaximize}>
        <Square size={12} />
      </WindowButton>
      <WindowButton label="Close window" onClick={onClose} danger>
        <X size={14} />
      </WindowButton>
    </div>
  )
}

function WindowButton({ label, onClick, danger, children }: { label: string; onClick: () => void; danger?: boolean; children: ReactNode }) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className={cn('flex size-8 items-center justify-center rounded-[8px] text-muted-foreground transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/60', danger && 'hover:bg-destructive/10 hover:text-destructive')}
    >
      {children}
    </button>
  )
}
