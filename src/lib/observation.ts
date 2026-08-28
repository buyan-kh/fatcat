export type LikelyUserState = 'typing' | 'meeting' | 'focused' | 'idle' | 'unknown'

export type PrivacyDecision = {
  redacted: boolean
  reason: string
  rawScreenshotRetained: boolean
}

export type ScreenObservation = {
  activeApp: string
  visibleWindow: string
  task: string
  detectedEvent: string
  repeatedActivity: string
  likelyUserState: LikelyUserState
  confidence: number
  timestamp: string
  privacy: PrivacyDecision
}

type ObservationInput = {
  activeApp: string
  visibleWindow: string
  task: string
  detectedEvent: string
  repeatedActivity?: string
  likelyUserState?: LikelyUserState
  confidence?: number
  privateApps?: string[]
  screenshotRetention?: boolean
}

export function buildObservation(input: ObservationInput): ScreenObservation {
  const privateApp = input.privateApps?.some((app) => app.toLowerCase() === input.activeApp.toLowerCase()) ?? false
  return {
    activeApp: privateApp ? '[private app]' : input.activeApp,
    visibleWindow: privateApp ? '[redacted]' : input.visibleWindow,
    task: privateApp ? '[redacted]' : input.task,
    detectedEvent: privateApp ? 'private context' : input.detectedEvent,
    repeatedActivity: input.repeatedActivity ?? 'none',
    likelyUserState: input.likelyUserState ?? 'unknown',
    confidence: input.confidence ?? 0.72,
    timestamp: new Date().toISOString(),
    privacy: {
      redacted: privateApp,
      reason: privateApp ? 'Active application is on the private-app exclusion list.' : 'Local structured context only.',
      rawScreenshotRetained: input.screenshotRetention ?? false,
    },
  }
}

