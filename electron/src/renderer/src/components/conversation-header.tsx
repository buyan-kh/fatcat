import { FolderOpen, WifiHigh, WifiSlash } from '@phosphor-icons/react'
import type { ConnectionStatus, ConversationRecord } from '@shared/chat'
import { Button } from '@renderer/components/ui/button'
import { cn } from '@renderer/lib/utils'

type ConversationHeaderProps = {
  conversation?: ConversationRecord
  connection: ConnectionStatus
  onChooseWorkspace: () => void
}

export function ConversationHeader({ conversation, connection, onChooseWorkspace }: ConversationHeaderProps) {
  const connected = connection.phase === 'connected'
  return (
    <header className="app-drag flex h-12 shrink-0 items-center gap-3 border-b px-4">
      <div className="min-w-0 flex-1">
        <p className="truncate text-[13px] font-medium">{conversation?.title ?? 'New conversation'}</p>
        <button
          type="button"
          className="app-no-drag flex max-w-full items-center gap-1 truncate text-[11px] text-muted-foreground hover:text-foreground"
          aria-label="Choose workspace"
          title={conversation?.workspacePath}
          onClick={onChooseWorkspace}
        >
          <FolderOpen className="size-3 shrink-0" />
          <span className="truncate">{conversation?.workspacePath ?? 'Choose a workspace'}</span>
        </button>
      </div>
      <Button variant="ghost" size="sm" className="app-no-drag h-7 gap-1.5 px-2 text-xs text-muted-foreground" title={connection.detail}>
        {connected ? <WifiHigh className="size-3.5 text-emerald-500" /> : <WifiSlash className="size-3.5" />}
        <span>{connected ? 'Connected' : 'Offline'}</span>
      </Button>
    </header>
  )
}
