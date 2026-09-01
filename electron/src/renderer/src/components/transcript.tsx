import { useEffect, useRef, useState } from 'react'
import { ArrowDown } from '@phosphor-icons/react/ArrowDown'
import { ChatCircleDots } from '@phosphor-icons/react/ChatCircleDots'
import { WarningCircle } from '@phosphor-icons/react/WarningCircle'
import { WifiSlash } from '@phosphor-icons/react/WifiSlash'
import type { ChatMessage, ConnectionStatus } from '@shared/chat'
import { Button } from '@renderer/components/ui/button'
import { MessageRow } from './message-row'

type TranscriptProps = {
  messages: ChatMessage[]
  connection: ConnectionStatus
  resumeError: string | null
  onSuggestion: (text: string) => void
  onRetry: () => void
  onNewChat: () => void
}

export function Transcript({ messages, connection, resumeError, onSuggestion, onRetry, onNewChat }: TranscriptProps) {
  const viewport = useRef<HTMLDivElement>(null)
  const [nearBottom, setNearBottom] = useState(true)

  useEffect(() => {
    if (!nearBottom || !viewport.current) return
    viewport.current.scrollTop = viewport.current.scrollHeight
  }, [messages, nearBottom])

  const jumpToLatest = () => {
    if (viewport.current) viewport.current.scrollTop = viewport.current.scrollHeight
    setNearBottom(true)
  }

  return (
    <div className="relative min-h-0 flex-1">
      <div
        ref={viewport}
        className="h-full overflow-y-auto overscroll-contain px-5"
        onScroll={(event) => {
          const element = event.currentTarget
          setNearBottom(element.scrollHeight - element.scrollTop - element.clientHeight < 72)
        }}
      >
        <div className="mx-auto flex min-h-full w-full max-w-3xl flex-col justify-center pb-8 pt-12">
          {connection.phase !== 'connected' && (
            <div className="surface-card mb-4 flex items-center gap-2 px-3 py-2 text-xs leading-5 text-muted-foreground">
              <WifiSlash className="size-4" /><span className="flex-1">{connection.detail}</span><Button variant="ghost" size="xs" onClick={onRetry}>Reconnect</Button>
            </div>
          )}
          {resumeError ? (
            <div className="mx-auto max-w-md text-center">
              <WarningCircle className="mx-auto mb-3 size-7 text-destructive" />
              <h2 className="text-base font-medium">This conversation could not be restored</h2>
              <p className="mt-2 text-sm text-muted-foreground">{resumeError}</p>
              <div className="mt-4 flex justify-center gap-2"><Button variant="outline" onClick={onRetry}>Retry</Button><Button onClick={onNewChat}>Start new chat</Button></div>
            </div>
          ) : messages.length === 0 ? (
            <div className="mx-auto max-w-lg text-center">
              <div className="surface-card mx-auto mb-3 flex size-10 items-center justify-center"><ChatCircleDots className="size-5" /></div>
              <h2 className="text-lg font-medium tracking-tight">What are you working on?</h2>
              <p className="mt-1 text-sm leading-6 text-muted-foreground">Start a focused conversation with Hermes.</p>
              <div className="mt-3 flex flex-wrap justify-center gap-2">
                {['Help me plan this task', 'Explain this codebase', 'Review my approach'].map((suggestion) => <Button key={suggestion} variant="outline" size="sm" className="nav-control" onClick={() => onSuggestion(suggestion)}>{suggestion}</Button>)}
              </div>
            </div>
          ) : (
            <div className="mt-auto space-y-6 pb-2">
              {messages.map((item) => <MessageRow key={item.id} message={item} onCopy={copyText} onRetry={onRetry} />)}
            </div>
          )}
        </div>
      </div>
      {!nearBottom && (
        <Button variant="outline" size="sm" className="absolute bottom-3 left-1/2 -translate-x-1/2 bg-background shadow-md" onClick={jumpToLatest}><ArrowDown />Jump to latest</Button>
      )}
    </div>
  )
}

function copyText(text: string): void {
  void navigator.clipboard?.writeText(text)
}
