import { ArrowClockwise } from '@phosphor-icons/react/ArrowClockwise'
import { Copy } from '@phosphor-icons/react/Copy'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import type { ChatMessage } from '@shared/chat'
import { Button } from '@renderer/components/ui/button'
import { TurnActivity } from './turn-activity'

type MessageRowProps = {
  message: ChatMessage
  onCopy: (text: string) => void
  onRetry: () => void
}

export function MessageRow({ message, onCopy, onRetry }: MessageRowProps) {
  if (message.role === 'system') {
    return <div className="surface-card mx-auto max-w-xl rounded-[10px] px-3 py-2 text-xs text-muted-foreground">{message.text}</div>
  }
  const user = message.role === 'user'
  return (
    <article className={`group/message flex w-full gap-3 ${user ? 'justify-end' : 'justify-start'}`} aria-label={user ? 'You' : 'FatCat'}>
      {!user && <div className="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-foreground text-[10px] font-bold text-background">F</div>}
      <div className={`min-w-0 ${user ? 'max-w-[78%]' : 'max-w-[min(720px,calc(100%-36px))] flex-1'}`}>
        {!user && <TurnActivity activities={message.activities} />}
        {user ? (
          <div className="rounded-[10px] rounded-br-[4px] border-[0.5px] border-border/70 bg-muted/80 px-3.5 py-2.5 text-sm leading-6">{message.text}</div>
        ) : (
          <div className="fatcat-markdown text-[13px] leading-6">
            {message.text ? (
              <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                components={{
                  a: ({ children, node: _node, ...props }) => <a {...props} target="_blank" rel="noreferrer" className="text-primary underline underline-offset-2">{children}</a>,
                  pre: ({ children }) => <pre className="surface-card my-3 overflow-x-auto rounded-[10px] p-3 font-mono text-xs">{children}</pre>,
                  code: ({ children, className, node: _node, ...props }) => <code {...props} className={`${className ?? ''} rounded bg-muted px-1 py-0.5 font-mono text-[0.9em]`}>{children}</code>,
                }}
              >{message.text}</ReactMarkdown>
            ) : <span className="text-muted-foreground">Thinking…</span>}
            {message.isStreaming && <span className="ml-1 inline-block h-4 w-0.5 animate-pulse bg-foreground/60 align-middle" aria-label="Streaming" />}
          </div>
        )}
        {message.errorMessage && (
          <div className="hairline mt-2 flex items-center gap-2 rounded-[10px] border border-destructive/25 bg-destructive/5 px-3 py-2 text-xs text-destructive">
            <span className="flex-1">{message.errorMessage}</span>
            <Button variant="ghost" size="xs" onClick={onRetry}>Retry</Button>
          </div>
        )}
        <div className={`mt-1 flex h-7 items-center gap-1 opacity-0 transition-opacity group-hover/message:opacity-100 focus-within:opacity-100 ${user ? 'justify-end' : ''}`}>
          <Button variant="ghost" size="icon-xs" aria-label="Copy message" onClick={() => onCopy(message.text)}><Copy /></Button>
          {!user && <Button variant="ghost" size="icon-xs" aria-label="Retry response" onClick={onRetry}><ArrowClockwise /></Button>}
        </div>
      </div>
    </article>
  )
}
