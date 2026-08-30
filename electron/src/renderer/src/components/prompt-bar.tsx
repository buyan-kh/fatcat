import { useState } from 'react'
import { ArrowUp } from '@phosphor-icons/react/ArrowUp'
import { FolderOpen } from '@phosphor-icons/react/FolderOpen'
import { Stop } from '@phosphor-icons/react/Stop'
import { Button } from '@renderer/components/ui/button'
import { Textarea } from '@renderer/components/ui/textarea'

type PromptBarProps = {
  workspacePath?: string
  isGenerating: boolean
  disabled: boolean
  onSend: (text: string) => void
  onStop: () => void
  onChooseWorkspace: () => void
}

export function PromptBar({ workspacePath, isGenerating, disabled, onSend, onStop, onChooseWorkspace }: PromptBarProps) {
  const [draft, setDraft] = useState('')
  const submit = () => {
    const normalized = draft.trim()
    if (!normalized || disabled || isGenerating) return
    onSend(normalized)
    setDraft('')
  }
  return (
    <div className="mx-auto w-full max-w-3xl px-5 pb-5">
      <div className="rounded-xl border bg-card shadow-[0_8px_30px_color-mix(in_oklab,var(--foreground)_8%,transparent)] focus-within:ring-2 focus-within:ring-ring/35">
        <Textarea
          aria-label="Message FatCat"
          placeholder={disabled ? 'Connect Hermes to continue' : 'Ask FatCat anything…'}
          value={draft}
          disabled={disabled}
          onChange={(event) => setDraft(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter' && !event.shiftKey) {
              event.preventDefault()
              submit()
            }
          }}
          className="min-h-12 max-h-40 resize-none border-0 bg-transparent px-3.5 pt-3 text-sm shadow-none focus-visible:ring-0 dark:bg-transparent"
        />
        <div className="flex items-center gap-2 px-2.5 pb-2.5">
          <Button variant="ghost" size="sm" className="min-w-0 max-w-[60%] justify-start gap-1.5 px-2 text-xs text-muted-foreground" aria-label="Choose workspace" title={workspacePath} onClick={onChooseWorkspace}>
            <FolderOpen className="size-3.5 shrink-0" /><span className="truncate">{workspacePath || 'Choose workspace'}</span>
          </Button>
          <span className="ml-auto hidden text-[10px] text-muted-foreground sm:block">Return to send · Shift-Return for newline</span>
          {isGenerating ? (
            <Button size="icon-sm" aria-label="Stop generation" onClick={onStop}><Stop className="size-3.5" weight="fill" /></Button>
          ) : (
            <Button size="icon-sm" aria-label="Send message" disabled={disabled || !draft.trim()} onClick={submit}><ArrowUp className="size-4" weight="bold" /></Button>
          )}
        </div>
      </div>
    </div>
  )
}
