import { useEffect, useState } from 'react'
import type { AgentDiagnostics } from '@shared/api'
import { AppSidebar } from '@renderer/components/app-sidebar'
import { ConversationHeader } from '@renderer/components/conversation-header'
import { PromptBar } from '@renderer/components/prompt-bar'
import { SettingsDialog } from '@renderer/components/settings-dialog'
import { Transcript } from '@renderer/components/transcript'
import { Button } from '@renderer/components/ui/button'
import { TooltipProvider } from '@renderer/components/ui/tooltip'
import { WindowControls } from '@renderer/components/window-controls'
import { useFatCat } from '@renderer/hooks/use-fatcat'
import { useAppearance } from '@renderer/hooks/use-appearance'

export default function App() {
  const { state, commands } = useFatCat()
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [windowMaximized, setWindowMaximized] = useState(false)
  const [diagnostics, setDiagnostics] = useState<AgentDiagnostics>()
  const snapshot = state.snapshot
  const selected = snapshot?.conversations.find((conversation) => conversation.id === snapshot.selectedId)
  useAppearance(snapshot?.appearance)

  useEffect(() => {
    void Promise.resolve(commands.isWindowMaximized()).then((value) => {
      if (typeof value === 'boolean') setWindowMaximized(value)
    })
  }, [commands])

  const openSettings = () => {
    setSettingsOpen(true)
    void commands.getDiagnostics().then((value) => { if (value) setDiagnostics(value) })
  }

  const chooseWorkspace = async () => {
    const workspace = await commands.chooseWorkspace()
    if (workspace) await commands.createConversation(workspace)
  }

  if (!snapshot) {
    return (
      <main className="flex h-full items-center justify-center bg-background">
        <div className="w-full max-w-sm text-center"><h1 className="text-lg font-semibold">FatCat</h1><p className="mt-2 text-sm text-muted-foreground">{state.notice?.message ?? 'Connecting to Hermes…'}</p>{state.phase === 'failed' && <Button className="mt-4" onClick={() => window.location.reload()}>Retry startup</Button>}</div>
      </main>
    )
  }

  return (
    <TooltipProvider>
      <main className="flex h-full min-w-[900px] bg-background text-foreground">
        <AppSidebar
          conversations={snapshot.conversations}
          selectedId={snapshot.selectedId}
          collapsed={sidebarCollapsed}
          connection={snapshot.connection}
          onNewChat={() => { void commands.createConversation() }}
          onSelect={(id) => { void commands.selectConversation(id) }}
          onRename={(id, currentTitle) => {
            const title = window.prompt('Rename conversation', currentTitle)?.trim()
            if (title) void commands.renameConversation(id, title)
          }}
          onDelete={(id) => { if (window.confirm('Delete this conversation?')) void commands.deleteConversation(id) }}
          onToggle={() => setSidebarCollapsed((value) => !value)}
          onOpenSettings={openSettings}
        />
        <section className="flex min-w-0 flex-1 flex-col">
          <ConversationHeader
            conversation={selected}
            connection={snapshot.connection}
            onChooseWorkspace={() => { void chooseWorkspace() }}
            windowMaximized={windowMaximized}
            onMinimize={() => { void commands.minimizeWindow() }}
            onToggleMaximize={() => { void Promise.resolve(commands.toggleMaximizeWindow()).then((value) => { if (typeof value === 'boolean') setWindowMaximized(value) }) }}
            onClose={() => { void commands.closeWindow() }}
          />
          <Transcript
            messages={snapshot.messages}
            connection={snapshot.connection}
            resumeError={snapshot.resumeError}
            onSuggestion={(text) => { void commands.sendMessage(text) }}
            onRetry={() => { snapshot.connection.phase === 'connected' ? void commands.retryLastTurn() : void commands.restartAgent() }}
            onNewChat={() => { void commands.createConversation() }}
          />
          <PromptBar
            workspacePath={selected?.workspacePath}
            isGenerating={snapshot.isGenerating}
            disabled={!selected?.hermesSessionId || snapshot.connection.phase !== 'connected'}
            onSend={(text) => { void commands.sendMessage(text) }}
            onStop={() => { void commands.cancelTurn() }}
            onChooseWorkspace={() => { void chooseWorkspace() }}
          />
        </section>
        <SettingsDialog
          open={settingsOpen}
          onOpenChange={setSettingsOpen}
          appearance={snapshot.appearance}
          providers={snapshot.providers}
          diagnostics={diagnostics}
          onAppearanceChange={(appearance) => { void commands.setAppearance(appearance) }}
          onRestartAgent={() => { void commands.restartAgent() }}
        />
        {state.notice && <button type="button" className="fixed bottom-5 right-5 max-w-sm rounded-[10px] border-[0.5px] bg-popover px-3 py-2 text-left text-xs leading-5 shadow-lg" onClick={commands.clearNotice}>{state.notice.message}</button>}
      </main>
    </TooltipProvider>
  )
}
