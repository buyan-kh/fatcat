import { fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import type { ChatMessage } from '@shared/chat'
import { MessageRow } from './message-row'
import { PromptBar } from './prompt-bar'
import { Transcript } from './transcript'

const assistant: ChatMessage = {
  id: 'm1',
  role: 'assistant',
  text: 'Hello **FatCat**. Visit [docs](https://example.com).',
  requestId: 'r1',
  isStreaming: false,
  activities: [{
    id: 'tool-1',
    requestId: 'r1',
    kind: 'tool',
    label: 'read_file',
    arguments: { path: 'README.md' },
    detail: 'Read complete.',
    status: 'completed',
  }],
}

describe('conversation experience', () => {
  it('renders markdown and expandable Hermes tool activity', async () => {
    const user = userEvent.setup()
    render(<MessageRow message={assistant} onCopy={vi.fn()} onRetry={vi.fn()} />)
    expect(screen.getByText('FatCat', { selector: 'strong' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'docs' })).toHaveAttribute('href', 'https://example.com')
    await user.click(screen.getByRole('button', { name: /read_file/ }))
    expect(screen.getByText('README.md', { selector: 'code' })).toBeInTheDocument()
    expect(screen.getByText('Read complete.')).toBeInTheDocument()
  })

  it('sends with Return, preserves Shift-Return, and switches to Stop while generating', async () => {
    const user = userEvent.setup()
    const onSend = vi.fn()
    const { rerender } = render(
      <PromptBar workspacePath="/tmp/fatcat" isGenerating={false} disabled={false} onSend={onSend} onStop={vi.fn()} onChooseWorkspace={vi.fn()} />,
    )
    const composer = screen.getByRole('textbox', { name: 'Message FatCat' })
    await user.type(composer, 'Hello')
    fireEvent.keyDown(composer, { key: 'Enter', shiftKey: true })
    expect(onSend).not.toHaveBeenCalled()
    fireEvent.keyDown(composer, { key: 'Enter' })
    expect(onSend).toHaveBeenCalledWith('Hello')

    rerender(<PromptBar workspacePath="/tmp/fatcat" isGenerating disabled={false} onSend={onSend} onStop={vi.fn()} onChooseWorkspace={vi.fn()} />)
    expect(screen.getByRole('button', { name: 'Stop generation' })).toBeInTheDocument()
  })

  it('shows a useful empty state and recoverable resume error', async () => {
    const onSuggestion = vi.fn()
    const { rerender } = render(
      <Transcript messages={[]} connection={{ phase: 'connected', detail: 'Connected' }} resumeError={null} onSuggestion={onSuggestion} onRetry={vi.fn()} onNewChat={vi.fn()} />,
    )
    expect(screen.getByText('What are you working on?')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Help me plan this task' }))
    expect(onSuggestion).toHaveBeenCalledWith('Help me plan this task')

    rerender(<Transcript messages={[]} connection={{ phase: 'connected', detail: 'Connected' }} resumeError="Session unavailable" onSuggestion={onSuggestion} onRetry={vi.fn()} onNewChat={vi.fn()} />)
    expect(screen.getByText('Session unavailable')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Start new chat' })).toBeInTheDocument()
  })
})
