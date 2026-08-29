export type ConversationRecord = {
  id: string
  hermesSessionId?: string
  title: string
  createdAt: string
  updatedAt: string
  lastPreview: string
  workspacePath: string
}

export type ChatRole = 'user' | 'assistant' | 'system'
export type TurnState = 'sending' | 'thinking' | 'working' | 'streaming' | 'completed' | 'failed' | 'cancelled'

export type TurnActivity = {
  id: string
  requestId: string
  kind: 'state' | 'plan' | 'tool'
  label: string
  detail?: string
  arguments?: Record<string, string>
  steps?: string[]
  status: TurnState
}

export type ChatMessage = {
  id: string
  role: ChatRole
  text: string
  requestId?: string
  isStreaming: boolean
  errorMessage?: string
  activities: TurnActivity[]
}

export type ConnectionStatus = {
  phase: 'starting' | 'connecting' | 'connected' | 'offline' | 'failed' | 'stopped'
  detail: string
  attempt?: number
}

export type AppearancePreference = 'system' | 'light' | 'dark'

export type ProviderSummary = {
  providerId: string
  name: string
  status: string
  detail: string
  model: string
  isDefault: boolean
}
