import type { FatCatAPI } from '../shared/api'

declare global {
  interface Window {
    fatcat?: FatCatAPI
  }
}

export {}
