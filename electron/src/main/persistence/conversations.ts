import { open as openFile, readFile, rename } from 'node:fs/promises'
import { dirname, extname, basename, join } from 'node:path'
import { randomUUID } from 'node:crypto'
import { z } from 'zod'
import type { ConversationRecord } from '../../shared/chat'

const recordSchema = z.object({
  id: z.string().min(1),
  hermesSessionId: z.string().min(1).optional(),
  title: z.string().min(1),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
  lastPreview: z.string(),
  workspacePath: z.string().min(1),
})

const documentSchema = z.object({
  selectedId: z.string().nullable(),
  records: z.array(recordSchema),
})

export type ConversationSnapshot = {
  selectedId: string | null
  records: ConversationRecord[]
}

type ConversationUpdate = {
  title?: string
  lastPreview?: string
}

const emptyDocument = (): ConversationSnapshot => ({ selectedId: null, records: [] })

export class ConversationRepository {
  private document: ConversationSnapshot
  private mutations: Promise<void> = Promise.resolve()

  private constructor(private readonly filePath: string, document: ConversationSnapshot) {
    this.document = document
  }

  static async open(filePath: string): Promise<ConversationRepository> {
    try {
      const contents = await readFile(filePath, 'utf8')
      const raw = JSON.parse(contents) as unknown
      const document = documentSchema.parse(raw)
      // Conversation records are metadata-only. Rewrite older documents that
      // embedded transcript bodies so Electron cannot become a second history
      // store alongside Hermes.
      if (JSON.stringify(raw) !== JSON.stringify(document)) {
        await atomicWrite(filePath, JSON.stringify(document, null, 2))
      }
      return new ConversationRepository(filePath, document)
    } catch (error) {
      if (isMissingFile(error)) return new ConversationRepository(filePath, emptyDocument())
      await quarantine(filePath)
      return new ConversationRepository(filePath, emptyDocument())
    }
  }

  async snapshot(): Promise<ConversationSnapshot> {
    await this.mutations
    return structuredClone(this.document)
  }

  async replace(snapshot: ConversationSnapshot): Promise<void> {
    documentSchema.parse(snapshot)
    await this.mutate((document) => {
      document.selectedId = snapshot.selectedId
      document.records = structuredClone(snapshot.records)
    })
  }

  async create(title: string, workspacePath: string): Promise<ConversationRecord> {
    const normalizedTitle = title.trim()
    if (!normalizedTitle) throw new Error('Conversation title is required')
    if (!workspacePath.trim()) throw new Error('Workspace path is required')
    const now = new Date().toISOString()
    const record: ConversationRecord = {
      id: randomUUID(),
      title: normalizedTitle,
      createdAt: now,
      updatedAt: now,
      lastPreview: '',
      workspacePath,
    }
    await this.mutate((document) => {
      document.records.unshift(record)
      document.selectedId = record.id
    })
    return structuredClone(record)
  }

  async select(id: string): Promise<void> {
    await this.mutate((document) => {
      requireRecord(document, id)
      document.selectedId = id
    })
  }

  async attachSession(id: string, hermesSessionId: string): Promise<void> {
    if (!hermesSessionId.trim()) throw new Error('Hermes session ID is required')
    await this.mutate((document) => {
      const record = requireRecord(document, id)
      record.hermesSessionId = hermesSessionId
      record.updatedAt = new Date().toISOString()
    })
  }

  async update(id: string, update: ConversationUpdate): Promise<void> {
    const title = update.title?.trim()
    if (update.title !== undefined && !title) throw new Error('Conversation title is required')
    await this.mutate((document) => {
      const record = requireRecord(document, id)
      if (title) record.title = title
      if (update.lastPreview !== undefined) record.lastPreview = update.lastPreview
      record.updatedAt = new Date().toISOString()
      document.records.sort((left, right) => right.updatedAt.localeCompare(left.updatedAt))
    })
  }

  async delete(id: string): Promise<void> {
    await this.mutate((document) => {
      requireRecord(document, id)
      document.records = document.records.filter((record) => record.id !== id)
      if (document.selectedId === id) document.selectedId = document.records[0]?.id ?? null
    })
  }

  async search(query: string): Promise<ConversationRecord[]> {
    const document = await this.snapshot()
    const normalized = query.trim().toLowerCase()
    if (!normalized) return document.records
    return document.records.filter((record) =>
      `${record.title}\n${record.lastPreview}`.toLowerCase().includes(normalized),
    )
  }

  private async mutate(change: (document: ConversationSnapshot) => void): Promise<void> {
    const operation = this.mutations.then(async () => {
      const next = structuredClone(this.document)
      change(next)
      documentSchema.parse(next)
      await atomicWrite(this.filePath, JSON.stringify(next, null, 2))
      this.document = next
    })
    this.mutations = operation.catch(() => undefined)
    return operation
  }
}

function requireRecord(document: ConversationSnapshot, id: string): ConversationRecord {
  const record = document.records.find((candidate) => candidate.id === id)
  if (!record) throw new Error(`Conversation not found: ${id}`)
  return record
}

async function atomicWrite(filePath: string, contents: string): Promise<void> {
  // Native and Electron clients can persist the same metadata cache at once.
  // A shared `.tmp` name lets one writer rename the other writer's file out
  // from under it, producing ENOENT and leaving the UI with stale state.
  const temporaryPath = `${filePath}.${process.pid}.${randomUUID()}.tmp`
  const handle = await openFile(temporaryPath, 'w')
  try {
    await handle.writeFile(contents, 'utf8')
    await handle.sync()
  } finally {
    await handle.close()
  }
  await rename(temporaryPath, filePath)
}

async function quarantine(filePath: string): Promise<void> {
  const extension = extname(filePath)
  const stem = basename(filePath, extension)
  const target = join(dirname(filePath), `${stem}.corrupt-${Date.now()}${extension}`)
  try {
    await rename(filePath, target)
  } catch (error) {
    if (!isMissingFile(error)) throw error
  }
}

function isMissingFile(error: unknown): boolean {
  return typeof error === 'object' && error !== null && 'code' in error && error.code === 'ENOENT'
}
