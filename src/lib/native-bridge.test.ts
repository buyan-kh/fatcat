import { describe, expect, it, vi } from 'vitest'
import { applyNativePrivacyConfig, createNativeBridgeConfig, isCaptureActive, type NativeBridge } from './native-bridge'

describe('native bridge configuration', () => {
  it('builds an explicit privacy payload with raw screenshot retention permanently disabled', () => {
    expect(createNativeBridgeConfig(['Messages', '1Password'])).toEqual({
      privateApps: ['Messages', '1Password'],
      rawScreenshotRetentionEnabled: false,
    })
  })

  it('propagates private-app exclusions to the native host', () => {
    const setPrivateApps = vi.fn()
    const bridge: NativeBridge = { setPrivateApps }

    applyNativePrivacyConfig(bridge, ['Calendar'])

    expect(setPrivateApps).toHaveBeenCalledWith(['Calendar'])
  })

  it('shows observing only when the native stream is actually capturing', () => {
    expect(isCaptureActive(true, { authorized: false, capturing: false, paused: false, status: 'Waiting' }, true)).toBe(false)
    expect(isCaptureActive(true, { authorized: true, capturing: true, paused: false, status: 'Connected' }, false)).toBe(true)
    expect(isCaptureActive(true, { authorized: true, capturing: false, paused: true, status: 'Paused' }, true)).toBe(false)
    expect(isCaptureActive(false, undefined, true)).toBe(true)
  })
})
