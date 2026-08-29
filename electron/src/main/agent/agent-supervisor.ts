import { EventEmitter, once } from 'node:events'
import { access, mkdir, rm } from 'node:fs/promises'
import { constants } from 'node:fs'
import { dirname } from 'node:path'
import { spawn, type ChildProcess, type SpawnOptions } from 'node:child_process'
import { SocketTransport } from './socket-transport'

type SpawnProcess = (command: string, args: readonly string[], options: SpawnOptions) => ChildProcess

export type AgentDiagnostics = {
  agentPath: string
  socketPath: string
  running: boolean
  lines: string[]
}

type AgentSupervisorOptions = {
  agentPath: string
  socketPath: string
  hermesHome: string
  spawnProcess?: SpawnProcess
  connectAttempts?: number
  connectDelayMs?: number
}

export class AgentSupervisor extends EventEmitter {
  private child?: ChildProcess
  private transport?: SocketTransport
  private readonly diagnostics: string[] = []
  private exited = false
  private readonly spawnProcess: SpawnProcess
  private readonly connectAttempts: number
  private readonly connectDelayMs: number

  constructor(private readonly options: AgentSupervisorOptions) {
    super()
    this.spawnProcess = options.spawnProcess ?? ((command, args, spawnOptions) => spawn(command, args, spawnOptions))
    this.connectAttempts = options.connectAttempts ?? 50
    this.connectDelayMs = options.connectDelayMs ?? 100
  }

  async start(): Promise<SocketTransport> {
    if (this.transport?.isConnected) return this.transport
    try {
      await access(this.options.agentPath, constants.X_OK)
    } catch {
      throw new Error(`FatCat Agent is unavailable at ${this.options.agentPath}. Set FATCAT_AGENT_PATH to a bundled executable.`)
    }
    await mkdir(this.options.hermesHome, { recursive: true })
    await mkdir(dirname(this.options.socketPath), { recursive: true })
    await rm(this.options.socketPath, { force: true })

    this.exited = false
    const child = this.spawnProcess(
      this.options.agentPath,
      ['--socket', this.options.socketPath, '--hermes-home', this.options.hermesHome],
      { env: process.env, stdio: ['ignore', 'pipe', 'pipe'] },
    )
    this.child = child
    child.stdout?.setEncoding('utf8')
    child.stderr?.setEncoding('utf8')
    child.stdout?.on('data', (chunk: string | Buffer) => this.recordDiagnostic(String(chunk)))
    child.stderr?.on('data', (chunk: string | Buffer) => this.recordDiagnostic(String(chunk)))
    child.on('exit', () => {
      this.exited = true
      this.emit('exit')
    })

    let lastError: unknown
    for (let attempt = 1; attempt <= this.connectAttempts; attempt += 1) {
      if (this.exited) break
      const transport = new SocketTransport(this.options.socketPath, { handshakeTimeoutMs: Math.max(250, this.connectDelayMs * 4) })
      try {
        await transport.connect()
        this.transport = transport
        return transport
      } catch (error) {
        lastError = error
        transport.close()
        if (attempt < this.connectAttempts) await delay(this.connectDelayMs)
      }
    }
    await this.forceStop()
    throw new Error(`FatCat Agent did not become ready: ${errorMessage(lastError)}`)
  }

  async restart(): Promise<SocketTransport> {
    await this.stop()
    return this.start()
  }

  async stop(graceMs = 1200): Promise<void> {
    const transport = this.transport
    if (transport?.isConnected) {
      const acknowledged = new Promise<void>((resolve) => {
        const listener = (event: { type: string }) => {
          if (event.type === 'shutdown_ack') {
            transport.off('event', listener)
            resolve()
          }
        }
        transport.on('event', listener)
      })
      transport.send({ version: 1, type: 'shutdown' })
      await Promise.race([acknowledged, delay(graceMs)])
    }
    if (this.child && !this.exited) {
      await Promise.race([once(this, 'exit').then(() => undefined), delay(Math.min(graceMs, 400))])
    }
    if (this.child && !this.exited) this.child.kill('SIGTERM')
    if (this.child && !this.exited) {
      await Promise.race([once(this, 'exit').then(() => undefined), delay(200)])
    }
    if (this.child && !this.exited) this.child.kill('SIGKILL')
    transport?.close()
    this.transport = undefined
    this.child = undefined
    await rm(this.options.socketPath, { force: true })
  }

  getDiagnostics(): AgentDiagnostics {
    return {
      agentPath: this.options.agentPath,
      socketPath: this.options.socketPath,
      running: Boolean(this.child && !this.exited),
      lines: [...this.diagnostics],
    }
  }

  private recordDiagnostic(value: string): void {
    for (const line of redactDiagnostic(value).split(/\r?\n/).filter(Boolean)) this.diagnostics.push(line)
    if (this.diagnostics.length > 80) this.diagnostics.splice(0, this.diagnostics.length - 80)
  }

  private async forceStop(): Promise<void> {
    this.transport?.close()
    if (this.child && !this.exited) this.child.kill('SIGKILL')
    this.child = undefined
    this.transport = undefined
    await rm(this.options.socketPath, { force: true })
  }
}

export function redactDiagnostic(value: string): string {
  return value
    .replace(/((?:API_KEY|ACCESS_TOKEN|REFRESH_TOKEN|PASSWORD|COOKIE|SECRET)\s*[=:]\s*)[^\s]+/gi, '$1[REDACTED]')
    .slice(0, 4096)
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error ?? 'unknown error')
}
