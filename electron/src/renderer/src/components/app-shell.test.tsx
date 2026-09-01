import { fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import type { ConversationRecord } from '@shared/chat'
import { AppSidebar } from './app-sidebar'
import { ConversationHeader } from './conversation-header'

const conversations: ConversationRecord[] = [
  { id: 'c1', title: 'First project', createdAt: '2026-08-29T00:00:00.000Z', updatedAt: '2026-08-29T00:00:00.000Z', lastPreview: 'Build a window', workspacePath: '/tmp/first' },
  { id: 'c2', title: 'Second idea', createdAt: '2026-08-28T00:00:00.000Z', updatedAt: '2026-08-28T00:00:00.000Z', lastPreview: 'Explore an avatar', workspacePath: '/tmp/second' },
]

describe('application shell', () => {
  it('supports new chat, selection, search, and collapse from the sidebar', async () => {
    const user = userEvent.setup()
    const onNewChat = vi.fn()
    const onSelect = vi.fn()
    const onToggle = vi.fn()
    render(
      <AppSidebar
        conversations={conversations}
        selectedId="c1"
        collapsed={false}
        connection={{ phase: 'connected', detail: 'Connected' }}
        onNewChat={onNewChat}
        onSelect={onSelect}
        onRename={vi.fn()}
        onDelete={vi.fn()}
        onToggle={onToggle}
        onOpenSettings={vi.fn()}
      />,
    )

    expect(screen.getByRole('heading', { name: 'FatCat' })).toBeInTheDocument()
    expect(screen.getByRole('searchbox', { name: 'Search chats' })).toHaveClass('nav-control')
    expect(screen.getByRole('button', { name: 'New chat' })).toHaveClass('nav-control')
    await user.click(screen.getByRole('button', { name: 'New chat' }))
    expect(onNewChat).toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: /^Second idea\./ }))
    expect(onSelect).toHaveBeenCalledWith('c2')
    await user.type(screen.getByRole('searchbox', { name: 'Search chats' }), 'avatar')
    expect(screen.queryByText('First project')).not.toBeInTheDocument()
    expect(screen.getByText('Second idea')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Collapse sidebar' }))
    expect(onToggle).toHaveBeenCalled()
  })

  it('shows the selected workspace and connection state in the header', () => {
    const onChooseWorkspace = vi.fn()
    render(
      <ConversationHeader
        conversation={conversations[0]}
        connection={{ phase: 'offline', detail: 'Hermes disconnected' }}
        onChooseWorkspace={onChooseWorkspace}
      />,
    )
    expect(screen.getByText('First project')).toBeInTheDocument()
    expect(screen.getByText('/tmp/first')).toBeInTheDocument()
    expect(screen.getByText('Offline')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Choose workspace' }))
    expect(onChooseWorkspace).toHaveBeenCalled()
  })
})
