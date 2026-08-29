import { mkdtemp, readdir, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { beforeEach, describe, expect, it } from 'vitest'
import { ConversationRepository } from './conversations'

describe('ConversationRepository', () => {
  let root: string
  let filePath: string

  beforeEach(async () => {
    root = await mkdtemp(join(tmpdir(), 'fatcat-conversations-'))
    filePath = join(root, 'conversations.json')
  })

  it('creates, selects, updates, persists, searches, and deletes records', async () => {
    const repository = await ConversationRepository.open(filePath)
    const first = await repository.create('First chat', '/tmp/first')
    const second = await repository.create('Second chat', '/tmp/second')

    expect((await repository.snapshot()).records.map((record) => record.id)).toEqual([second.id, first.id])
    expect((await repository.snapshot()).selectedId).toBe(second.id)

    await repository.attachSession(first.id, 'session-1')
    await repository.update(first.id, { title: 'Renamed chat', lastPreview: 'A useful answer' })
    await repository.select(first.id)
    expect(await repository.search('useful')).toHaveLength(1)

    const reopened = await ConversationRepository.open(filePath)
    expect((await reopened.snapshot()).records.find((record) => record.id === first.id)).toMatchObject({
      title: 'Renamed chat',
      lastPreview: 'A useful answer',
      hermesSessionId: 'session-1',
      workspacePath: '/tmp/first',
    })

    await reopened.delete(first.id)
    expect((await reopened.snapshot()).selectedId).toBe(second.id)
    expect((await reopened.snapshot()).records).toHaveLength(1)
    expect((await readdir(root)).some((name) => name.endsWith('.tmp'))).toBe(false)
  })

  it('returns immutable snapshots', async () => {
    const repository = await ConversationRepository.open(filePath)
    await repository.create('Chat', '/tmp/project')
    const snapshot = await repository.snapshot()
    snapshot.records[0]!.title = 'Mutated outside'
    expect((await repository.snapshot()).records[0]!.title).toBe('Chat')
  })

  it('quarantines corrupt data and starts empty', async () => {
    await writeFile(filePath, '{broken')
    const repository = await ConversationRepository.open(filePath)

    expect(await repository.snapshot()).toEqual({ selectedId: null, records: [] })
    expect((await readdir(root)).some((name) => name.startsWith('conversations.corrupt-'))).toBe(true)
  })

  it('rejects unknown records and blank updates', async () => {
    const repository = await ConversationRepository.open(filePath)
    await expect(repository.select('missing')).rejects.toThrow('Conversation not found')
    await expect(repository.create('   ', '/tmp/project')).rejects.toThrow('Conversation title is required')
  })
})
