export type InterruptionReason =
  | 'verified_completion'
  | 'serious_error'
  | 'repeated_blockage'
  | 'approaching_deadline'
  | 'dangerous_action'
  | 'directly_relevant_discovery'
  | 'explicit_proactive_mode'
  | 'background_update'

export type InterruptionInput = {
  reason: InterruptionReason
  confidence: number
  inCooldown: boolean
  userIsTyping: boolean
  inMeeting?: boolean
}

export function decideInterruption(input: InterruptionInput): { interrupt: boolean; reason: string } {
  const actionable = new Set<InterruptionReason>([
    'verified_completion',
    'serious_error',
    'repeated_blockage',
    'approaching_deadline',
    'dangerous_action',
    'directly_relevant_discovery',
    'explicit_proactive_mode',
  ])
  if (!actionable.has(input.reason)) return { interrupt: false, reason: 'Background updates are silent.' }
  if (input.inCooldown) return { interrupt: false, reason: 'Cooldown is active.' }
  if (input.userIsTyping || input.inMeeting) return { interrupt: false, reason: 'The user is busy; stay silent.' }
  if (input.confidence < 0.8 && input.reason !== 'explicit_proactive_mode') return { interrupt: false, reason: 'Confidence is below the interruption threshold.' }
  return { interrupt: true, reason: `Actionable: ${input.reason.replaceAll('_', ' ')}.` }
}

