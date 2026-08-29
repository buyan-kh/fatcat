import { z } from 'zod'

const id = z.string().min(1)
const optionalRequestId = z.string().nullable().optional()
const base = { version: z.literal(1) }

const hello = z.object({ ...base, type: z.literal('hello') }).strict()
const newSession = z.object({ ...base, type: z.literal('new_session'), request_id: id, conversation_id: id, cwd: z.string().min(1) }).strict()
const loadSession = z.object({ ...base, type: z.literal('load_session'), request_id: id, conversation_id: id, session_id: id, cwd: z.string().min(1) }).strict()
const listSessions = z.object({ ...base, type: z.literal('list_sessions'), request_id: id, cwd: z.string().nullable() }).strict()
const userMessage = z.object({ ...base, type: z.literal('user_message'), request_id: id, session_id: id, text: z.string().min(1) }).strict()
const cancel = z.object({ ...base, type: z.literal('cancel'), request_id: id, session_id: id }).strict()
const providerInventory = z.object({ ...base, type: z.literal('provider_inventory'), request_id: id }).strict()
const providerModels = z.object({ ...base, type: z.literal('provider_models'), request_id: id, provider_id: id, refresh: z.boolean() }).strict()
const providerSetDefault = z.object({ ...base, type: z.literal('provider_set_default'), request_id: id, provider_id: id, model: id }).strict()
const providerSetCredentialRef = z.object({ ...base, type: z.literal('provider_set_credential_ref'), request_id: id, provider_id: id, credential_ref: id }).strict()
const providerSetBaseUrl = z.object({ ...base, type: z.literal('provider_set_base_url'), request_id: id, provider_id: id, base_url: z.string() }).strict()
const providerValidate = z.object({ ...base, type: z.literal('provider_validate'), request_id: id, provider_id: id, model: id }).strict()
const shutdown = z.object({ ...base, type: z.literal('shutdown') }).strict()

export const clientCommandSchema = z.discriminatedUnion('type', [
  hello,
  newSession,
  loadSession,
  listSessions,
  userMessage,
  cancel,
  providerInventory,
  providerModels,
  providerSetDefault,
  providerSetCredentialRef,
  providerSetBaseUrl,
  providerValidate,
  shutdown,
])

const helloAck = z.object({ ...base, type: z.literal('hello_ack'), agent_version: z.string() }).strict()
const sessionReady = z.object({ ...base, type: z.literal('session_ready'), request_id: id, conversation_id: id, session_id: id }).strict()
const sessionLoaded = z.object({ ...base, type: z.literal('session_loaded'), request_id: id, conversation_id: id, session_id: id }).strict()
const sessionLoadFailed = z.object({ ...base, type: z.literal('session_load_failed'), request_id: id, conversation_id: id, session_id: id, message: z.string() }).strict()
const sessionHistory = z.object({ ...base, type: z.literal('session_history'), conversation_id: id, session_id: id, role: z.enum(['user', 'assistant', 'system']), text: z.string() }).strict()
const sessionList = z.object({ ...base, type: z.literal('session_list'), request_id: id, sessions: z.array(z.record(z.string(), z.string())) }).strict()
const assistantDelta = z.object({ ...base, type: z.literal('assistant_delta'), request_id: id, session_id: id, text: z.string() }).strict()
const plan = z.object({ ...base, type: z.literal('plan'), request_id: optionalRequestId, session_id: id, steps: z.array(z.string()) }).strict()
const toolCall = z.object({ ...base, type: z.literal('tool_call'), request_id: id, name: z.string(), arguments: z.record(z.string(), z.string()) }).strict()
const actionResult = z.object({ ...base, type: z.literal('action_result'), request_id: id, success: z.boolean(), detail: z.string() }).strict()
const verificationResult = z.object({ ...base, type: z.literal('verification_result'), request_id: id, success: z.boolean(), detail: z.string() }).strict()
const state = z.object({ ...base, type: z.literal('state'), state: z.enum(['sending', 'thinking', 'working', 'streaming', 'completed', 'failed', 'cancelled', 'idle']), session_id: id.optional(), request_id: optionalRequestId }).strict()
const permissionRequest = z.object({ ...base, type: z.enum(['permission_request', 'proposed_action']), request_id: id, action: z.string(), risk: z.string(), reason: z.string() }).strict()
const providerStatus = z.object({ ...base, type: z.literal('provider_status'), provider_id: id, authenticated: z.boolean(), detail: z.string() }).strict()
const providerDescriptor = z.record(z.string(), z.string())
const providerInventoryResult = z.object({ ...base, type: z.literal('provider_inventory_result'), request_id: id, providers: z.array(providerDescriptor) }).strict()
const providerModelsResult = z.object({ ...base, type: z.literal('provider_models_result'), request_id: id, provider_id: id, models: z.array(z.string()) }).strict()
const providerConfigured = z.object({ ...base, type: z.literal('provider_configured'), request_id: id, operation: z.string(), provider: id, model: z.string().nullable().optional(), credential_ref: z.string().nullable().optional(), base_url: z.string().optional() }).strict()
const providerValidationResult = z.object({ ...base, type: z.literal('provider_validation_result'), request_id: id, provider: id, model: id, usable: z.boolean(), detail: z.string() }).strict()
const memoryUpdate = z.object({ ...base, type: z.literal('memory_update'), session_id: id, detail: z.string() }).strict()
const errorEvent = z.object({ ...base, type: z.literal('error'), request_id: optionalRequestId, message: z.string() }).strict()
const shutdownAck = z.object({ ...base, type: z.literal('shutdown_ack') }).strict()

export const agentEventSchema = z.discriminatedUnion('type', [
  helloAck,
  sessionReady,
  sessionLoaded,
  sessionLoadFailed,
  sessionHistory,
  sessionList,
  assistantDelta,
  plan,
  toolCall,
  actionResult,
  verificationResult,
  state,
  permissionRequest,
  providerStatus,
  providerInventoryResult,
  providerModelsResult,
  providerConfigured,
  providerValidationResult,
  memoryUpdate,
  errorEvent,
  shutdownAck,
])

export type ClientCommand = z.infer<typeof clientCommandSchema>
export type AgentEvent = z.infer<typeof agentEventSchema>

const forbiddenKeys = new Set(['api_key', 'access_token', 'refresh_token', 'cookie', 'password', 'secret'])

export function assertNoCredentials(value: unknown, path = ''): void {
  if (Array.isArray(value)) {
    value.forEach((child, index) => assertNoCredentials(child, `${path}${index}.`))
    return
  }
  if (!value || typeof value !== 'object') return
  for (const [key, child] of Object.entries(value)) {
    if (forbiddenKeys.has(key.toLowerCase())) throw new Error(`Credential field is not allowed: ${path}${key}`)
    assertNoCredentials(child, `${path}${key}.`)
  }
}

export function decodeAgentEvent(line: string): AgentEvent {
  let value: unknown
  try {
    value = JSON.parse(line)
  } catch {
    throw new Error('Invalid agent event: malformed JSON')
  }
  assertNoCredentials(value)
  if (value && typeof value === 'object' && 'version' in value && value.version !== 1) {
    throw new Error(`Unsupported protocol version: ${String(value.version)}`)
  }
  const result = agentEventSchema.safeParse(value)
  if (!result.success) throw new Error(`Invalid agent event: ${result.error.issues[0]?.message ?? 'schema mismatch'}`)
  return result.data
}

export function encodeClientCommand(command: ClientCommand): string {
  assertNoCredentials(command)
  const parsed = clientCommandSchema.safeParse(command)
  if (!parsed.success) throw new Error(`Invalid client command: ${parsed.error.issues[0]?.message ?? 'schema mismatch'}`)
  return `${JSON.stringify(parsed.data)}\n`
}
