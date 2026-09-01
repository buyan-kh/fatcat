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
export type TurnState = 'sending' | 'thinking' | 'working' | 'streaming' | 'stopping' | 'completed' | 'failed' | 'cancelled'

export const hermesEventKinds = [
  'message.started',
  'message.delta',
  'message.completed',
  'tool.started',
  'tool.progress',
  'tool.needs_approval',
  'tool.completed',
  'tool.failed',
  'native_action.proposed',
  'native_action.approval_requested',
  'native_action.result',
  'verification.completed',
  'session.state',
  'session.error',
  'memory.updated',
] as const

export type HermesEventKind = (typeof hermesEventKinds)[number]
export type HermesEventDetail = string | number | boolean | null | string[]
export type HermesEvent = {
  version: 2
  event_id: string
  kind: HermesEventKind
  session_id: string
  request_id?: string | null
  summary: string
  details: Record<string, HermesEventDetail>
}

export type ToolLifecycleState = 'started' | 'progress' | 'needs_approval' | 'completed' | 'failed'

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
