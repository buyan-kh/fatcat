import { useState, type ReactNode } from 'react'
import { Archive } from '@phosphor-icons/react/Archive'
import { CaretDown } from '@phosphor-icons/react/CaretDown'
import { GearSix } from '@phosphor-icons/react/GearSix'
import { House } from '@phosphor-icons/react/House'
import { MagnifyingGlass } from '@phosphor-icons/react/MagnifyingGlass'
import { PencilSimple } from '@phosphor-icons/react/PencilSimple'
import { SidebarSimple } from '@phosphor-icons/react/SidebarSimple'
import { UserPlus } from '@phosphor-icons/react/UserPlus'
import type { ConnectionStatus, ConversationRecord } from '@shared/chat'
import { Button } from '@renderer/components/ui/button'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@renderer/components/ui/dropdown-menu'
import { cn } from '@renderer/lib/utils'
import SearchList from './search-list'

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

const SIDEBAR_WIDTH = 224
const COLLAPSED_WIDTH = 52

export function AppSidebar({ conversations, selectedId, collapsed, connection, onNewChat, onSelect, onRename, onDelete, onToggle, onOpenSettings }: AppSidebarProps) {
  const [searchOpen, setSearchOpen] = useState(false)

  return (
    <aside
      aria-label="Workspace navigation"
      data-sidebar-collapsed={collapsed}
      className="relative flex h-full shrink-0 overflow-hidden border-r-[0.5px] border-border/70 bg-muted/20 transition-[width] duration-300"
      style={{ width: collapsed ? COLLAPSED_WIDTH : SIDEBAR_WIDTH, transitionTimingFunction: 'cubic-bezier(0.16,1,0.3,1)' }}
    >
      <div className="flex min-h-0 w-56 shrink-0 flex-col">
        <div className="relative mb-2.5 h-10 shrink-0">
          <div className="absolute left-2 top-1 flex h-9 w-[164px] items-center rounded-[10px] px-2 text-left">
            <span className="flex size-5 shrink-0 items-center justify-center rounded-[7px] bg-foreground text-[10px] font-semibold text-background">F</span>
            <h1 className="ml-1.5 min-w-0 truncate text-sm font-medium text-foreground">FatCat</h1>
          </div>
          <button type="button" aria-label="Collapse sidebar" aria-hidden={collapsed} tabIndex={collapsed ? -1 : 0} onClick={onToggle} className="absolute right-2 top-1 flex size-9 items-center justify-center rounded-[10px] text-muted-foreground transition-colors hover:bg-accent hover:text-foreground">
            <SidebarSimple className="size-[18px]" />
          </button>
          <button type="button" aria-label="Expand sidebar" aria-hidden={!collapsed} tabIndex={collapsed ? 0 : -1} onClick={onToggle} className="absolute left-2 top-0.5 flex size-9 items-center justify-center rounded-[10px] text-muted-foreground transition-colors hover:bg-accent hover:text-foreground">
            <SidebarSimple className="size-[18px] rotate-180" />
          </button>
        </div>

        <div className="flex flex-col gap-px">
          <RailButton icon={<PencilSimple size={18} />} label="New chat" onClick={onNewChat} className="nav-control" />
          <RailButton icon={<House size={18} />} label="Home" />
          <RailButton icon={<UserPlus size={18} />} label="Invite users" count="3/10" />
        </div>

        {!collapsed && <div className="mt-8 min-h-0 flex-1 overflow-y-auto">
          <div className="relative mx-2 mb-1 h-8">
            <div className={cn('absolute inset-0 flex items-center gap-1.5 px-2 text-[12.5px] font-medium text-muted-foreground transition-opacity', searchOpen && 'pointer-events-none opacity-0')}>
              <CaretDown size={16} /><span>Chats</span>
            </div>
            {!searchOpen && <button type="button" aria-label="Search chats" onClick={() => setSearchOpen(true)} className="absolute right-0 top-0 flex size-9 items-center justify-center rounded-[10px] text-muted-foreground hover:bg-accent hover:text-foreground"><MagnifyingGlass size={16} /></button>}
          </div>

          {searchOpen ? <SearchList
            className="min-h-0 max-w-none"
            items={conversations.map((conversation) => conversation.title)}
            labels={{ placeholder: 'Search chats', ariaLabel: 'Search chats', emptyTitle: 'No chats found', emptyHint: 'Adjust your search to try again' }}
            matches={(item, value, index) => `${conversations[index]?.title ?? item}\n${conversations[index]?.lastPreview ?? ''}`.toLowerCase().includes(value.toLowerCase())}
            itemAriaLabel={(item, index) => `${item}. ${conversations[index]?.lastPreview ?? ''}`}
            onPick={(_item, index) => { const conversation = conversations[index]; if (conversation) onSelect(conversation.id) }}
          /> : <div className="group/sidebar flex flex-col gap-px">{conversations.map((conversation) => <RecentRow key={conversation.id} conversation={conversation} active={conversation.id === selectedId} onSelect={onSelect} onRename={onRename} onDelete={onDelete} />)}</div>}
        </div>}

        <div className={cn('mx-2 mt-8 border-t-[0.5px] border-border/70 pt-3', collapsed && 'border-transparent')}>
          <button type="button" onClick={onOpenSettings} aria-label="Settings" className={cn('flex h-9 w-full items-center gap-1 rounded-[10px] px-2 text-[13px] font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground', collapsed && 'justify-center px-0')}>
            <GearSix size={17} />
            {!collapsed && <><span className="flex-1 text-left">Settings</span><span className={cn('size-1.5 rounded-full', connection.phase === 'connected' ? 'bg-emerald-500' : 'bg-muted-foreground')} /></>}
          </button>
        </div>
      </div>
    </aside>
  )
}

function RailButton({ icon, label, count, onClick, className }: { icon: ReactNode; label: string; count?: string; onClick?: () => void; className?: string }) {
  return <button type="button" onClick={onClick} className={cn('mx-2 flex h-9 items-center gap-1 rounded-[10px] px-2 text-left text-[13px] font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground', className)}><span className="flex size-5 shrink-0 items-center justify-center">{icon}</span><span className="min-w-0 flex-1 truncate">{label}</span>{count && <span className="mr-2 shrink-0 text-[12px] tabular-nums text-muted-foreground">{count}</span>}</button>
}

function RecentRow({ conversation, active, onSelect, onRename, onDelete }: { conversation: ConversationRecord; active: boolean; onSelect: (id: string) => void; onRename: (id: string, title: string) => void; onDelete: (id: string) => void }) {
  return <div className={cn('group relative mx-2 flex h-9 items-center rounded-[10px] transition-colors', active ? 'bg-accent' : 'hover:bg-accent/70')}>
    <button type="button" title={conversation.title} aria-label={`${conversation.title}. ${conversation.lastPreview}`} onClick={() => onSelect(conversation.id)} className="min-w-0 flex-1 truncate rounded-[10px] px-2 text-left text-[13px] leading-5 font-medium text-foreground/80 outline-none focus-visible:ring-2 focus-visible:ring-ring">{conversation.title}</button>
    <DropdownMenu>
      <DropdownMenuTrigger asChild><Button variant="ghost" size="icon-xs" aria-label={`Actions for ${conversation.title}`} className="mr-1 opacity-0 group-hover:opacity-100 data-[state=open]:opacity-100"><Archive className="size-3.5" /></Button></DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-36"><DropdownMenuItem onSelect={() => onRename(conversation.id, conversation.title)}>Rename</DropdownMenuItem><DropdownMenuItem variant="destructive" onSelect={() => onDelete(conversation.id)}>Delete</DropdownMenuItem></DropdownMenuContent>
    </DropdownMenu>
  </div>
}
