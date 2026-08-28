export const actionKinds = [
  'inspect_state',
  'explain_error',
  'open_file',
  'highlight_ui',
  'type_text',
  'edit_document',
  'move_file',
  'rename_file',
  'send',
  'publish',
  'delete',
  'spend',
  'destructive_command',
] as const

export type ActionKind = (typeof actionKinds)[number]
export type RiskLevel = 'low' | 'medium' | 'high'

export type ActionRequest = {
  id: string
  kind: ActionKind
  label: string
  detail?: string
  expectedResult?: string
}

const riskByAction: Record<ActionKind, RiskLevel> = {
  inspect_state: 'low',
  explain_error: 'low',
  open_file: 'low',
  highlight_ui: 'low',
  type_text: 'medium',
  edit_document: 'medium',
  move_file: 'medium',
  rename_file: 'medium',
  send: 'high',
  publish: 'high',
  delete: 'high',
  spend: 'high',
  destructive_command: 'high',
}

export function classifyAction(action: ActionRequest): RiskLevel {
  return riskByAction[action.kind]
}

export type EnforcementResult = {
  allowed: boolean
  requiresApproval: boolean
  risk: RiskLevel
  reason: string
}

export function enforceAction(action: ActionRequest, approved: boolean): EnforcementResult {
  const risk = classifyAction(action)
  if (risk === 'low') {
    return { allowed: true, requiresApproval: false, risk, reason: 'Low-risk local inspection may run autonomously.' }
  }
  if (!approved) {
    return { allowed: false, requiresApproval: true, risk, reason: `${risk === 'high' ? 'High-risk' : 'Medium-risk'} action is waiting for explicit approval.` }
  }
  if (risk === 'high') {
    return { allowed: false, requiresApproval: true, risk, reason: 'High-risk actions always require explicit approval at execution time.' }
  }
  return { allowed: true, requiresApproval: true, risk, reason: 'Approved medium-risk action may run once and must be verified.' }
}

