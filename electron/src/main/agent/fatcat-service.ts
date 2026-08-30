import { EventEmitter } from 'node:events'
import { homedir } from 'node:os'
import { randomUUID } from 'node:crypto'
import type { AgentDiagnostics, AppSnapshot, FatCatEvent } from '../../shared/api'
import type { AppearancePreference, ChatMessage, ConnectionStatus, ConversationRecord, ProviderSummary, TurnActivity, TurnState } from '../../shared/chat'
import type { AgentEvent, ClientCommand } from '../../shared/protocol'
import type { ConversationRepository } from '../persistence/conversations'

type AgentTransport = EventEmitter & {
  readonly isConnected: boolean
  send(command: ClientCommand): void
}

type FatCatServiceOptions = {
  repository: ConversationRepository
  transport: AgentTransport
  chooseWorkspace: () => Promise<string | null>
  diagnostics: () => Promise<AgentDiagnostics>
  restartAgent?: () => Promise<AgentTransport>
  defaultWorkspace?: string
  appearance?: AppearancePreference
}

export class FatCatService extends EventEmitter {
  private transport: AgentTransport
  private messages: ChatMessage[] = []
  private connection: ConnectionStatus = { phase: 'connected', detail: 'Connected' }
  private activeRequestId: string | null = null
  private ignoredRequestIds = new Set<string>()
  private retryPrompt: string | null = null
  private resumeError: string | null = null
  private providers: ProviderSummary[] = []
  private appearance: AppearancePreference
  private eventChain: Promise<void> = Promise.resolve()

  constructor(private readonly options: FatCatServiceOptions) {
    super()
    this.transport = options.transport
    this.appearance = options.appearance ?? 'system'
    this.bindTransport(options.transport)
  }

  async snapshot(): Promise<AppSnapshot> {
    const document = await this.options.repository.snapshot()
    return {
      conversations: document.records,
      selectedId: document.selectedId,
      messages: structuredClone(this.messages),
      connection: { ...this.connection },
      activeRequestId: this.activeRequestId,
      isGenerating: this.activeRequestId !== null,
      resumeError: this.resumeError,
      providers: structuredClone(this.providers),
      appearance: this.appearance,
    }
  }

  async createConversation(workspacePath?: string): Promise<ConversationRecord> {
    const existing = await this.options.repository.snapshot()
    const workspace = workspacePath?.trim() || existing.records[0]?.workspacePath || this.options.defaultWorkspace || homedir()
    const record = await this.options.repository.create('New chat', workspace)
    this.messages = []
    this.resumeError = null
    this.activeRequestId = null
    this.transport.send({ version: 1, type: 'new_session', request_id: randomUUID(), conversation_id: record.id, cwd: workspace })
    await this.emitSnapshot()
    return record
  }

  async selectConversation(id: string): Promise<void> {
    await this.options.repository.select(id)
    const document = await this.options.repository.snapshot()
    const record = document.records.find((candidate) => candidate.id === id)
    if (!record) throw new Error(`Conversation not found: ${id}`)
    this.messages = []
    this.activeRequestId = null
    this.resumeError = null
    if (record.hermesSessionId) {
      this.transport.send({ version: 1, type: 'load_session', request_id: randomUUID(), conversation_id: record.id, session_id: record.hermesSessionId, cwd: record.workspacePath })
    } else {
      this.transport.send({ version: 1, type: 'new_session', request_id: randomUUID(), conversation_id: record.id, cwd: record.workspacePath })
    }
    await this.emitSnapshot()
  }

  async renameConversation(id: string, title: string): Promise<void> {
    await this.options.repository.update(id, { title })
    await this.emitSnapshot()
  }

  async deleteConversation(id: string): Promise<void> {
    const before = await this.options.repository.snapshot()
    const wasSelected = before.selectedId === id
    await this.options.repository.delete(id)
    if (wasSelected) {
      this.messages = []
      this.activeRequestId = null
      const after = await this.options.repository.snapshot()
      if (after.selectedId) await this.selectConversation(after.selectedId)
    }
    await this.emitSnapshot()
  }

  async sendMessage(text: string): Promise<void> {
    const normalized = text.trim()
    if (!normalized) throw new Error('Message is required')
    if (this.activeRequestId) throw new Error('A turn is already running')
    const document = await this.options.repository.snapshot()
    const record = document.records.find((candidate) => candidate.id === document.selectedId)
    if (!record?.hermesSessionId) throw new Error('Hermes session is not ready')
    const requestId = randomUUID()
    this.activeRequestId = requestId
    this.retryPrompt = normalized
    this.messages.push(message('user', normalized))
    this.transport.send({ version: 1, type: 'user_message', request_id: requestId, session_id: record.hermesSessionId, text: normalized })
    await this.options.repository.update(record.id, { lastPreview: normalized })
    await this.emitSnapshot()
  }

  async cancelTurn(): Promise<void> {
    if (!this.activeRequestId) return
    const document = await this.options.repository.snapshot()
    const record = document.records.find((candidate) => candidate.id === document.selectedId)
    if (!record?.hermesSessionId) return
    const cancelled = this.activeRequestId
    this.ignoredRequestIds.add(cancelled)
    this.activeRequestId = null
    const assistant = [...this.messages].reverse().find((item) => item.requestId === cancelled && item.role === 'assistant')
    if (assistant) {
      assistant.isStreaming = false
      assistant.activities.forEach((activity) => { if (activity.status !== 'completed') activity.status = 'cancelled' })
    }
    this.transport.send({ version: 1, type: 'cancel', request_id: randomUUID(), session_id: record.hermesSessionId })
    await this.emitSnapshot()
  }

  async retryLastTurn(): Promise<void> {
    if (!this.retryPrompt) throw new Error('There is no prompt to retry')
    await this.sendMessage(this.retryPrompt)
  }

  chooseWorkspace(): Promise<string | null> {
    return this.options.chooseWorkspace()
  }

  async setAppearance(appearance: AppearancePreference): Promise<void> {
    this.appearance = appearance
    await this.emitSnapshot()
  }

  async restartAgent(): Promise<void> {
    if (!this.options.restartAgent) throw new Error('Agent restart is unavailable')
    this.connection = { phase: 'connecting', detail: 'Reconnecting to Hermes…' }
    await this.emitSnapshot()
    const next = await this.options.restartAgent()
    this.transport = next
    this.bindTransport(next)
    this.connection = { phase: 'connected', detail: 'Connected' }
    const document = await this.options.repository.snapshot()
    if (document.selectedId) await this.selectConversation(document.selectedId)
    else await this.emitSnapshot()
  }

  getDiagnostics(): Promise<AgentDiagnostics> {
    return this.options.diagnostics()
  }

  private bindTransport(transport: AgentTransport): void {
    transport.on('event', (event: AgentEvent) => {
      this.eventChain = this.eventChain.then(() => this.handleAgentEvent(event)).catch((error) => {
        this.emit('event', { type: 'notice', level: 'error', message: errorMessage(error) } satisfies FatCatEvent)
      })
    })
    transport.on('status', (status: ConnectionStatus) => {
      this.connection = status
      void this.emitSnapshot()
    })
  }

  private async handleAgentEvent(event: AgentEvent): Promise<void> {
    if ('request_id' in event && event.request_id && this.ignoredRequestIds.has(event.request_id)) return
    const document = await this.options.repository.snapshot()
    const selected = document.records.find((record) => record.id === document.selectedId)

    switch (event.type) {
      case 'session_ready':
        if (event.conversation_id !== document.selectedId) return
        await this.options.repository.attachSession(event.conversation_id, event.session_id)
        this.resumeError = null
        break
      case 'session_loaded':
        if (event.conversation_id !== document.selectedId) return
        this.resumeError = null
        break
      case 'session_load_failed':
        if (event.conversation_id !== document.selectedId) return
        this.resumeError = event.message
        break
      case 'session_history':
        if (event.conversation_id !== document.selectedId || event.session_id !== selected?.hermesSessionId) return
        this.messages.push(message(event.role, event.text))
        if (event.role === 'user') this.retryPrompt = event.text
        break
      case 'assistant_delta': {
        if (event.session_id !== selected?.hermesSessionId || event.request_id !== this.activeRequestId) return
        const assistant = this.ensureAssistant(event.request_id)
        assistant.text += event.text
        assistant.isStreaming = true
        break
      }
      case 'plan': {
        if (event.session_id !== selected?.hermesSessionId || (event.request_id && event.request_id !== this.activeRequestId)) return
        const requestId = this.activeRequestId ?? event.request_id
        if (!requestId) return
        this.ensureAssistant(requestId).activities.push({ id: randomUUID(), requestId, kind: 'plan', label: 'Plan', steps: event.steps, status: 'working' })
        break
      }
      case 'tool_call': {
        if (!this.activeRequestId) return
        this.ensureAssistant(this.activeRequestId).activities.push({ id: event.request_id, requestId: this.activeRequestId, kind: 'tool', label: event.name, arguments: event.arguments, status: 'working' })
        break
      }
      case 'action_result': {
        const activity = this.messages.flatMap((item) => item.activities).find((item) => item.id === event.request_id)
        if (activity) {
          activity.detail = event.detail
          activity.status = event.success ? 'completed' : 'failed'
        }
        break
      }
      case 'state':
        if (!event.request_id || event.request_id !== this.activeRequestId || (event.session_id && event.session_id !== selected?.hermesSessionId)) return
        this.applyTurnState(event.request_id, event.state)
        if (event.state === 'completed' || event.state === 'failed' || event.state === 'error') {
          const assistant = [...this.messages].reverse().find((item) => item.requestId === event.request_id && item.role === 'assistant')
          if (assistant?.text) await this.options.repository.update(selected!.id, { lastPreview: assistant.text.slice(0, 180) })
          this.activeRequestId = null
        }
        break
      case 'error':
        if (event.request_id && event.request_id === this.activeRequestId) {
          const assistant = this.ensureAssistant(event.request_id)
          assistant.isStreaming = false
          assistant.errorMessage = event.message
          assistant.activities.forEach((activity) => { if (activity.status !== 'completed') activity.status = 'failed' })
          this.activeRequestId = null
        } else {
          this.emit('event', { type: 'notice', level: 'error', message: event.message } satisfies FatCatEvent)
        }
        break
      case 'provider_inventory_result':
        this.providers = event.providers.map((provider) => ({
          providerId: provider.slug ?? '',
          name: provider.name ?? provider.slug ?? 'Provider',
          status: provider.status ?? 'unknown',
          detail: provider.detail ?? '',
          model: provider.default_model ?? '',
          isDefault: provider.is_default === 'true',
        }))
        break
      default:
        break
    }
    await this.emitSnapshot()
  }

  private ensureAssistant(requestId: string): ChatMessage {
    const existing = [...this.messages].reverse().find((item) => item.role === 'assistant' && item.requestId === requestId)
    if (existing) return existing
    const next = message('assistant', '', requestId)
    next.isStreaming = true
    this.messages.push(next)
    return next
  }

  private applyTurnState(requestId: string, rawState: string): void {
    const state = normalizeTurnState(rawState)
    if (!state) return
    const assistant = this.ensureAssistant(requestId)
    assistant.isStreaming = !['completed', 'failed', 'cancelled'].includes(state)
    let activity = assistant.activities.find((item) => item.kind === 'state')
    if (!activity) {
      activity = { id: `state-${requestId}`, requestId, kind: 'state', label: stateLabel(state), status: state }
      assistant.activities.unshift(activity)
    } else {
      activity.label = stateLabel(state)
      activity.status = state
    }
    if (state === 'completed') {
      assistant.activities.forEach((item) => {
        if (item.kind === 'plan' && item.status === 'working') item.status = 'completed'
      })
    }
    if (state === 'failed') {
      assistant.activities.forEach((item) => {
        if (item.status === 'working') item.status = 'failed'
      })
    }
    if (state === 'failed') assistant.errorMessage ??= 'Hermes could not complete this turn.'
  }

  private async emitSnapshot(): Promise<void> {
    this.emit('event', { type: 'snapshot', snapshot: await this.snapshot() } satisfies FatCatEvent)
  }
}

function message(role: ChatMessage['role'], text: string, requestId?: string): ChatMessage {
  return { id: randomUUID(), role, text, requestId, isStreaming: false, activities: [] }
}

function normalizeTurnState(value: string): TurnState | null {
  if (value === 'stopping') return 'stopping'
  if (value === 'sending' || value === 'thinking' || value === 'working' || value === 'streaming' || value === 'completed' || value === 'failed') return value
  if (value === 'error') return 'failed'
  return null
}

function stateLabel(state: TurnState): string {
  return state === 'completed' ? 'Completed' : state === 'failed' ? 'Failed' : state === 'stopping' ? 'Stopping' : state[0]!.toUpperCase() + state.slice(1)
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}
