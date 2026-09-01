import type { AgentDiagnostics } from '@shared/api'
import type { AppearancePreference, ProviderSummary } from '@shared/chat'
import { Button } from '@renderer/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@renderer/components/ui/dialog'
import { Separator } from '@renderer/components/ui/separator'
import { cn } from '@renderer/lib/utils'

type SettingsDialogProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  appearance: AppearancePreference
  providers: ProviderSummary[]
  diagnostics?: AgentDiagnostics
  onAppearanceChange: (appearance: AppearancePreference) => void
  onRestartAgent: () => void
}

export function SettingsDialog({ open, onOpenChange, appearance, providers, diagnostics, onAppearanceChange, onRestartAgent }: SettingsDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>FatCat settings</DialogTitle>
          <DialogDescription>Appearance and read-only Hermes connection details.</DialogDescription>
        </DialogHeader>
        <section className="space-y-3">
          <h3 className="section-caption">Appearance</h3>
          <div className="grid grid-cols-3 gap-2">
            {(['system', 'light', 'dark'] as const).map((option) => (
              <Button key={option} variant={appearance === option ? 'default' : 'outline'} className={cn('nav-control capitalize', appearance === option && 'pointer-events-none')} onClick={() => onAppearanceChange(option)}>{option}</Button>
            ))}
          </div>
        </section>
        <Separator />
        <section className="space-y-2">
          <h3 className="section-caption">Hermes</h3>
          {providers.length > 0 ? providers.map((provider) => (
            <div key={provider.providerId} className="surface-card rounded-[10px] p-3 text-xs">
              <div className="flex items-center justify-between"><span className="font-medium">{provider.name}</span><span className="text-muted-foreground">{provider.status}</span></div>
              <p className="mt-1 text-muted-foreground">{provider.model || provider.detail}</p>
            </div>
          )) : <p className="text-xs text-muted-foreground">Provider details become available after Hermes connects.</p>}
          <Button variant="outline" onClick={onRestartAgent}>Restart Hermes</Button>
        </section>
        {diagnostics && (
          <><Separator /><section className="space-y-1 text-xs text-muted-foreground"><h3 className="section-caption">Diagnostics</h3><p className="truncate">Agent: {diagnostics.agentPath}</p><p>{diagnostics.running ? 'Running' : 'Stopped'} · {diagnostics.lines.length} diagnostic lines</p></section></>
        )}
      </DialogContent>
    </Dialog>
  )
}
