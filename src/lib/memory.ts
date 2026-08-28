export const memoryLayers = ['shortTerm', 'episodic', 'semantic', 'procedural'] as const
export type MemoryLayer = (typeof memoryLayers)[number]

export type MemoryEntry = {
  id: string
  content: string
  createdAt: string
  source: 'user_correction' | 'system' | 'observation' | 'learning_record'
  unreliable?: boolean
}

export type LayeredMemory = Record<MemoryLayer, MemoryEntry[]>
export const MEMORY_STORAGE_KEY = 'peppa-anywhere-memory-v1'

export function createEmptyMemory(): LayeredMemory {
  return { shortTerm: [], episodic: [], semantic: [], procedural: [] }
}

export function appendMemory(memory: LayeredMemory, layer: MemoryLayer, entry: MemoryEntry): LayeredMemory {
  return { ...memory, [layer]: [...memory[layer], entry] }
}

export function deleteMemory(memory: LayeredMemory, id: string): LayeredMemory {
  return Object.fromEntries(memoryLayers.map((layer) => [layer, memory[layer].filter((entry) => entry.id !== id)])) as LayeredMemory
}

export function readMemory(storage: Pick<Storage, 'getItem'>): LayeredMemory {
  try {
    const raw = storage.getItem(MEMORY_STORAGE_KEY)
    if (!raw) return createEmptyMemory()
    const parsed = JSON.parse(raw) as Partial<LayeredMemory>
    return Object.fromEntries(memoryLayers.map((layer) => [layer, Array.isArray(parsed[layer]) ? parsed[layer] : []])) as LayeredMemory
  } catch {
    return createEmptyMemory()
  }
}

export function writeMemory(storage: Pick<Storage, 'setItem'>, memory: LayeredMemory): void {
  try { storage.setItem(MEMORY_STORAGE_KEY, JSON.stringify(memory)) } catch { /* local-only memory is best effort */ }
}

