import { useMemo, useState } from 'react'
import {
  DotsThree,
  GearSix,
  MagnifyingGlass,
  PencilSimple,
  Plus,
  SidebarSimple,
  Trash,
} from '@phosphor-icons/react'
import type { ConnectionStatus, ConversationRecord } from '@shared/chat'
import { Button } from '@renderer/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@renderer/components/ui/dropdown-menu'
import { Input } from '@renderer/components/ui/input'
import { ScrollArea } from '@renderer/components/ui/scroll-area'
import { cn } from '@renderer/lib/utils'

type AppSidebarProps = {
  conversations: ConversationRecord[]
  selectedId: string | null
  collapsed: boolean
  connection: ConnectionStatus
  onNewChat: () => void
  onSelect: (id: string) => void
  onRename: (id: string, title: string) => void
  onDelete: (id: string) => void
  onToggle: () => void
  onOpenSettings: () => void
}

export function AppSidebar({
  conversations,
  selectedId,
  collapsed,
  connection,
  onNewChat,
  onSelect,
  onRename,
  onDelete,
  onToggle,
  onOpenSettings,
}: AppSidebarProps) {
  const [query, setQuery] = useState('')
  const visible = useMemo(() => {
    const normalized = query.trim().toLowerCase()
    if (!normalized) return conversations
    return conversations.filter((conversation) =>
      `${conversation.title}\n${conversation.lastPreview}`.toLowerCase().includes(normalized),
    )
  }, [conversations, query])

  return (
    <aside className={cn('flex h-full shrink-0 flex-col border-r bg-muted/35 transition-[width] duration-200', collapsed ? 'w-[68px]' : 'w-64')}>
      <div className="app-drag flex h-12 items-center gap-2 px-3 pl-[72px]">
        {!collapsed && <h1 className="text-sm font-semibold tracking-[-0.01em]">FatCat</h1>}
        <Button className="app-no-drag ml-auto" variant="ghost" size="icon-sm" aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'} onClick={onToggle}>
          <SidebarSimple className="size-4" />
        </Button>
      </div>

      <div className="px-2.5 pb-2">
        <Button className={cn('w-full justify-start shadow-none', collapsed && 'justify-center px-0')} variant="outline" onClick={onNewChat} aria-label="New chat">
          <Plus className="size-4" weight="bold" />
          {!collapsed && <span>New chat</span>}
        </Button>
      </div>

      {!collapsed && (
        <div className="relative px-2.5 pb-2">
          <MagnifyingGlass className="pointer-events-none absolute left-5 top-2.5 size-3.5 text-muted-foreground" />
          <Input
            type="search"
            aria-label="Search chats"
            placeholder="Search chats"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className="h-8 border-transparent bg-transparent pl-8 text-xs shadow-none hover:bg-background/60 focus-visible:border-border"
          />
        </div>
      )}

      <ScrollArea className="min-h-0 flex-1 px-2">
        {!collapsed && (
          <div className="space-y-0.5 pb-3">
            {visible.length === 0 && <p className="px-2 py-8 text-center text-xs text-muted-foreground">No chats found</p>}
            {visible.map((conversation) => (
              <div key={conversation.id} className={cn('group flex items-center rounded-md', selectedId === conversation.id ? 'bg-accent' : 'hover:bg-accent/70')}>
                <button
                  type="button"
                  className="min-w-0 flex-1 rounded-md px-2 py-2 text-left outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  aria-label={`${conversation.title}. ${conversation.lastPreview}`}
                  onClick={() => onSelect(conversation.id)}
                >
                  <span className="block truncate text-[13px] font-medium">{conversation.title}</span>
                  {conversation.lastPreview && <span className="mt-0.5 block truncate text-[11px] text-muted-foreground">{conversation.lastPreview}</span>}
                </button>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon-xs" aria-label={`Actions for ${conversation.title}`} className="mr-1 opacity-0 group-hover:opacity-100 data-[state=open]:opacity-100">
                      <DotsThree className="size-4" weight="bold" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end" className="w-36">
                    <DropdownMenuItem onSelect={() => onRename(conversation.id, conversation.title)}><PencilSimple />Rename</DropdownMenuItem>
                    <DropdownMenuItem variant="destructive" onSelect={() => onDelete(conversation.id)}><Trash />Delete</DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            ))}
          </div>
        )}
      </ScrollArea>

      <div className="border-t p-2">
        <Button variant="ghost" className={cn('w-full justify-start px-2', collapsed && 'justify-center')} onClick={onOpenSettings} aria-label="Settings">
          <GearSix className="size-4" />
          {!collapsed && <span className="flex-1 text-left">Settings</span>}
          {!collapsed && <span className={cn('size-1.5 rounded-full', connection.phase === 'connected' ? 'bg-emerald-500' : 'bg-muted-foreground')} aria-hidden />}
        </Button>
      </div>
    </aside>
  )
}
