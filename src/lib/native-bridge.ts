import type { ScreenObservation } from './observation'

export type NativeBridge = {
  requestScreenAccess?: () => void
  setObservationPaused?: (paused: boolean) => void
  setPrivateApps?: (apps: string[]) => void
  isAvailable?: () => boolean
}

export type NativeCaptureStatus = {
  authorized: boolean
  capturing: boolean
  paused: boolean
  status: string
}

export type NativePrivacyConfig = {
  privateApps: string[]
  rawScreenshotRetentionEnabled: false
}

export function createNativeBridgeConfig(privateApps: string[]): NativePrivacyConfig {
  return { privateApps: [...privateApps], rawScreenshotRetentionEnabled: false }
}

export function applyNativePrivacyConfig(bridge: NativeBridge | undefined, privateApps: string[]): void {
  bridge?.setPrivateApps?.([...privateApps])
}

export function isCaptureActive(native: boolean, status: NativeCaptureStatus | undefined, _fallback = false): boolean {
  // A missing native bridge is an unavailable capability, never a simulated
  // observation stream. Callers can label a separate demo surface explicitly.
  return native && status?.capturing === true && status.paused === false
}

type FatCatWindow = Window & {
  __FATCAT_NATIVE__?: NativeBridge
}

export function getNativeBridge(): NativeBridge | undefined {
  if (typeof window === 'undefined') return undefined
  return (window as FatCatWindow).__FATCAT_NATIVE__
}

export function subscribeNativeObservations(onObservation: (observation: ScreenObservation) => void): () => void {
  if (typeof window === 'undefined') return () => undefined
  const handler = (event: Event) => {
    const detail = (event as CustomEvent<ScreenObservation>).detail
    if (detail?.activeApp && detail.timestamp) onObservation(detail)
  }
  window.addEventListener('fatcat:observation', handler)
  return () => window.removeEventListener('fatcat:observation', handler)
}

export function subscribeNativeCaptureStatus(onStatus: (status: NativeCaptureStatus) => void): () => void {
  if (typeof window === 'undefined') return () => undefined
  const handler = (event: Event) => {
    const detail = (event as CustomEvent<NativeCaptureStatus>).detail
    if (typeof detail?.status === 'string') onStatus(detail)
  }
  window.addEventListener('fatcat:capture-status', handler)
  return () => window.removeEventListener('fatcat:capture-status', handler)
}
