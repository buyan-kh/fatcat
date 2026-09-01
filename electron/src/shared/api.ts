import type { AppearancePreference, ChatMessage, ConnectionStatus, ConversationRecord, ProviderSummary } from './chat'

export type AgentDiagnostics = {
  agentPath: string
  socketPath: string
  running: boolean
  lines: string[]
}

export type AppSnapshot = {
  conversations: ConversationRecord[]
  selectedId: string | null
  messages: ChatMessage[]
  connection: ConnectionStatus
  activeRequestId: string | null
  isGenerating: boolean
  resumeError: string | null
  providers: ProviderSummary[]
  appearance: AppearancePreference
}

export type FatCatEvent =
  | { type: 'snapshot'; snapshot: AppSnapshot }
  | { type: 'notice'; level: 'info' | 'error'; message: string }

export type FatCatAPI = {
  snapshot(): Promise<AppSnapshot>
  createConversation(workspacePath?: string): Promise<ConversationRecord>
  selectConversation(id: string): Promise<void>
  renameConversation(id: string, title: string): Promise<void>
  deleteConversation(id: string): Promise<void>
  sendMessage(text: string): Promise<void>
  cancelTurn(): Promise<void>
  approveAction(proposalId: string): Promise<void>
  denyAction(proposalId: string): Promise<void>
  retryLastTurn(): Promise<void>
  chooseWorkspace(): Promise<string | null>
  setAppearance(appearance: AppearancePreference): Promise<void>
  restartAgent(): Promise<void>
  getDiagnostics(): Promise<AgentDiagnostics>
  subscribe(listener: (event: FatCatEvent) => void): () => void
}

export const FATCAT_EVENT_CHANNEL = 'fatcat:event'

export const FATCAT_INVOKE_CHANNELS = {
  snapshot: 'fatcat:snapshot',
  createConversation: 'fatcat:create-conversation',
  selectConversation: 'fatcat:select-conversation',
  renameConversation: 'fatcat:rename-conversation',
  deleteConversation: 'fatcat:delete-conversation',
  sendMessage: 'fatcat:send-message',
  cancelTurn: 'fatcat:cancel-turn',
  approveAction: 'fatcat:approve-action',
  denyAction: 'fatcat:deny-action',
  retryLastTurn: 'fatcat:retry-last-turn',
  chooseWorkspace: 'fatcat:choose-workspace',
  setAppearance: 'fatcat:set-appearance',
  restartAgent: 'fatcat:restart-agent',
  getDiagnostics: 'fatcat:get-diagnostics',
} as const
