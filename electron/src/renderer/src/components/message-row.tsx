import { ArrowClockwise } from '@phosphor-icons/react/ArrowClockwise'
import { Copy } from '@phosphor-icons/react/Copy'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import type { ChatMessage } from '@shared/chat'
import { Button } from '@renderer/components/ui/button'
import { TurnActivity } from './turn-activity'
import { StreamingText } from './streaming-text'

type MessageRowProps = {
  message: ChatMessage
  onCopy: (text: string) => void
  onRetry: () => void
  onApprove?: (proposalId: string) => void
  onDeny?: (proposalId: string) => void
}

export function MessageRow({ message, onCopy, onRetry, onApprove = () => undefined, onDeny = () => undefined }: MessageRowProps) {
  if (message.role === 'system') {
    return <div className="surface-card mx-auto max-w-xl px-3 py-2 text-xs leading-5 text-muted-foreground">{message.text}</div>
  }
  const user = message.role === 'user'
  return (
    <article className={`group/message flex w-full gap-3 ${user ? 'justify-end' : 'justify-start'}`} aria-label={user ? 'You' : 'FatCat'}>
      {!user && <div className="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-foreground text-[10px] font-bold text-background">F</div>}
      <div className={`min-w-0 ${user ? 'max-w-[78%]' : 'max-w-[min(720px,calc(100%-36px))] flex-1'}`}>
        {!user && <TurnActivity activities={message.activities} onApprove={onApprove} onDeny={onDeny} />}
        {user ? (
          <div className="rounded-[10px] rounded-br-[4px] border-[0.5px] border-border/70 bg-muted/80 px-3.5 py-2.5 text-sm leading-6">{message.text}</div>
        ) : (
          <div className="fatcat-markdown text-[13px] leading-6">
            {message.isStreaming ? (
              <div className="streaming-response" aria-label="Streaming response">
                <div className="streaming-response-status" aria-hidden="true">
                  <span className="streaming-live-dot" />
                  <span className="streaming-response-label">{message.text ? 'Writing' : 'Waiting for response'}</span>
                </div>
                {message.text ? <StreamingText text={message.text} isStreaming /> : <span className="streaming-placeholder">The first words are on their way…</span>}
              </div>
            ) : message.text ? (
              <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                components={{
                  a: ({ children, node: _node, ...props }) => <a {...props} target="_blank" rel="noreferrer" className="text-primary underline underline-offset-2">{children}</a>,
                  pre: ({ children }) => <pre className="surface-card my-3 overflow-x-auto rounded-[10px] p-3 font-mono text-xs">{children}</pre>,
                  code: ({ children, className, node: _node, ...props }) => <code {...props} className={`${className ?? ''} rounded bg-muted px-1 py-0.5 font-mono text-[0.9em]`}>{children}</code>,
                }}
              >{message.text}</ReactMarkdown>
            ) : null}
          </div>
        )}
        {message.errorMessage && (
          <div className="hairline mt-2 flex items-center gap-2 rounded-[10px] border-[0.5px] border-destructive/25 bg-destructive/5 px-3 py-2 text-xs leading-5 text-destructive">
            <span className="flex-1">{message.errorMessage}</span>
            <Button variant="ghost" size="xs" onClick={onRetry}>Retry</Button>
          </div>
        )}
        <div className={`mt-1 flex h-7 items-center gap-1 transition-opacity duration-400 ${message.isStreaming ? 'pointer-events-none opacity-0' : 'opacity-100'} ${user ? 'justify-end' : ''}`}>
          <Button variant="ghost" size="icon-xs" aria-label="Copy message" onClick={() => onCopy(message.text)}><Copy /></Button>
          {!user && <Button variant="ghost" size="icon-xs" aria-label="Retry response" onClick={onRetry}><ArrowClockwise /></Button>}
        </div>
      </div>
    </article>
  )
}
