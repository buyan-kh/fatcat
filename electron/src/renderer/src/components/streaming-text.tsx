import BeautifulStreamingText from '../../../components/primitives/StreamingText'

type StreamingTextProps = {
  text: string
  isStreaming?: boolean
}

function tokensFor(text: string) {
  return text.split(/\s+/).filter(Boolean).map((token) => ({ text: token }))
}

/** Adapts the registry primitive to real Hermes delta text. */
export function StreamingText({ text }: StreamingTextProps) {
  return (
    <div className="beautifului-streaming" aria-label="Streaming response">
      <BeautifulStreamingText content={tokensFor(text)} sources={[]} followUps={[]} loop={false} fill />
    </div>
  )
}
