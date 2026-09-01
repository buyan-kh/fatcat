import { Fragment, useMemo } from 'react'

type StreamingTextProps = {
  text: string
  isStreaming: boolean
}

/** Renders real Hermes deltas with a subtle word-level resolve animation. */
export function StreamingText({ text, isStreaming }: StreamingTextProps) {
  const tokens = useMemo(() => text.match(/\S+\s*/g) ?? [], [text])
  return (
    <span aria-label={isStreaming ? 'Streaming response' : undefined}>
      {tokens.map((token, index) => (
        <Fragment key={`${index}-${token}`}>
          <span data-testid="streaming-token" data-streaming-token={isStreaming ? '' : undefined} className={isStreaming ? 'streaming-token' : undefined}>{token}</span>
        </Fragment>
      ))}
      {isStreaming && <span className="streaming-cursor" aria-hidden />}
    </span>
  )
}
