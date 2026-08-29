import { open as openFile, readFile, rename } from 'node:fs/promises'

export type WindowBounds = {
  x?: number
  y?: number
  width: number
  height: number
}

export type DisplayBounds = {
  x: number
  y: number
  width: number
  height: number
}

export const DEFAULT_WINDOW_BOUNDS: WindowBounds = { width: 1180, height: 760 }
export const MINIMUM_WINDOW_BOUNDS = { width: 900, height: 620 }

export function isVisibleBounds(bounds: WindowBounds, displays: DisplayBounds[]): boolean {
  if (!Number.isFinite(bounds.x) || !Number.isFinite(bounds.y)) return false
  const left = bounds.x as number
  const top = bounds.y as number
  const right = left + bounds.width
  const bottom = top + bounds.height
  return displays.some((display) => {
    const displayRight = display.x + display.width
    const displayBottom = display.y + display.height
    return right > display.x && left < displayRight && bottom > display.y && top < displayBottom
  })
}

export class WindowStateStore {
  private constructor(private readonly filePath: string, private bounds?: WindowBounds) {}

  static async open(filePath: string): Promise<WindowStateStore> {
    try {
      const value = JSON.parse(await readFile(filePath, 'utf8')) as WindowBounds
      if (!isBounds(value)) return new WindowStateStore(filePath)
      return new WindowStateStore(filePath, value)
    } catch {
      return new WindowStateStore(filePath)
    }
  }

  resolve(displays: DisplayBounds[]): WindowBounds {
    if (!this.bounds) return { ...DEFAULT_WINDOW_BOUNDS }
    const normalized = {
      ...this.bounds,
      width: Math.max(MINIMUM_WINDOW_BOUNDS.width, this.bounds.width),
      height: Math.max(MINIMUM_WINDOW_BOUNDS.height, this.bounds.height),
    }
    return isVisibleBounds(normalized, displays) ? normalized : { ...DEFAULT_WINDOW_BOUNDS }
  }

  async save(bounds: WindowBounds): Promise<void> {
    if (!isBounds(bounds)) throw new Error('Invalid window bounds')
    this.bounds = { ...bounds }
    const temporaryPath = `${this.filePath}.tmp`
    const handle = await openFile(temporaryPath, 'w')
    try {
      await handle.writeFile(JSON.stringify(bounds), 'utf8')
      await handle.sync()
    } finally {
      await handle.close()
    }
    await rename(temporaryPath, this.filePath)
  }
}

function isBounds(value: unknown): value is WindowBounds {
  if (!value || typeof value !== 'object') return false
  const candidate = value as Partial<WindowBounds>
  return Number.isFinite(candidate.width) && Number.isFinite(candidate.height) &&
    (candidate.x === undefined || Number.isFinite(candidate.x)) &&
    (candidate.y === undefined || Number.isFinite(candidate.y))
}
