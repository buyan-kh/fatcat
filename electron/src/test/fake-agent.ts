import { createServer, type Server, type Socket } from 'node:net'
import { rm } from 'node:fs/promises'
import type { ClientCommand } from '../shared/protocol'

export class FakeAgent {
  private server?: Server
  private client?: Socket
  private buffer = ''
  readonly commands: ClientCommand[] = []

  constructor(readonly socketPath: string, private readonly autoHandshake = true) {}

  async start(onCommand?: (command: ClientCommand, agent: FakeAgent) => void): Promise<void> {
    await rm(this.socketPath, { force: true })
    this.server = createServer((client) => {
      this.client = client
      client.setEncoding('utf8')
      client.on('data', (chunk: string) => {
        this.buffer += chunk
        let newline = this.buffer.indexOf('\n')
        while (newline >= 0) {
          const line = this.buffer.slice(0, newline)
          this.buffer = this.buffer.slice(newline + 1)
          if (line.trim()) {
            const command = JSON.parse(line) as ClientCommand
            this.commands.push(command)
            if (command.type === 'hello' && this.autoHandshake) {
              this.send({ version: 1, type: 'hello_ack', agent_version: 'fake-1' })
            }
            onCommand?.(command, this)
          }
          newline = this.buffer.indexOf('\n')
        }
      })
    })
    await new Promise<void>((resolve, reject) => {
      this.server!.once('error', reject)
      this.server!.listen(this.socketPath, resolve)
    })
  }

  send(event: object, splitAt?: number): void {
    const line = `${JSON.stringify(event)}\n`
    if (splitAt && splitAt > 0 && splitAt < line.length) {
      this.client?.write(line.slice(0, splitAt))
      this.client?.write(line.slice(splitAt))
    } else {
      this.client?.write(line)
    }
  }

  sendRaw(value: string): void {
    this.client?.write(value)
  }

  disconnect(): void {
    this.client?.destroy()
  }

  async stop(): Promise<void> {
    this.client?.destroy()
    await new Promise<void>((resolve) => this.server?.close(() => resolve()) ?? resolve())
    await rm(this.socketPath, { force: true })
  }
}
