import { EventEmitter } from 'node:events'
import { createConnection, type Socket } from 'node:net'
import { decodeAgentEvent, encodeClientCommand, type AgentEvent, type ClientCommand } from '../../shared/protocol'

type SocketTransportOptions = {
  handshakeTimeoutMs?: number
  reconnectDelayMs?: number
}

export class SocketTransport extends EventEmitter {
  private socket?: Socket
  private buffer = ''
  private ready = false
  private connecting?: Promise<void>
  private readonly handshakeTimeoutMs: number
  private readonly reconnectDelayMs: number
  private reconnectTimer?: NodeJS.Timeout
  private keepAlive = false

  constructor(readonly socketPath: string, options: SocketTransportOptions = {}) {
    super()
    this.handshakeTimeoutMs = options.handshakeTimeoutMs ?? 3000
    this.reconnectDelayMs = options.reconnectDelayMs ?? 500
  }

  get isConnected(): boolean {
    return this.ready && this.socket?.destroyed === false
  }

  connect(): Promise<void> {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = undefined
    }
    if (this.isConnected) return Promise.resolve()
    if (this.connecting) return this.connecting
    this.connecting = new Promise<void>((resolve, reject) => {
      let settled = false
      const finish = (error?: Error) => {
        if (settled) return
        settled = true
        clearTimeout(timeout)
        this.connecting = undefined
        if (error) reject(error)
        else resolve()
      }
      const timeout = setTimeout(() => {
        this.close()
        finish(new Error('FatCat Agent handshake timed out'))
      }, this.handshakeTimeoutMs)

      const socket = createConnection(this.socketPath)
      this.socket = socket
      socket.setEncoding('utf8')
      socket.on('connect', () => socket.write(encodeClientCommand({ version: 1, type: 'hello', client: 'electron_chat' })))
      socket.on('data', (chunk: string) => {
        if (this.socket === socket) this.consume(chunk, () => finish())
      })
      socket.on('error', (error) => {
        if (this.socket !== socket) return
        this.emit('status', { phase: 'offline', detail: error.message })
        finish(error)
      })
      socket.on('close', () => {
        if (this.socket !== socket) return
        const wasReady = this.ready
        this.ready = false
        this.socket = undefined
        this.emit('status', { phase: 'offline', detail: 'FatCat Agent disconnected.' })
        this.emit('disconnect')
        if (!wasReady) finish(new Error('FatCat Agent disconnected before handshake'))
        if (this.keepAlive) this.scheduleReconnect()
      })
    })
    return this.connecting
  }

  send(command: ClientCommand): void {
    if (!this.isConnected || !this.socket) throw new Error('FatCat Agent socket is not connected')
    this.socket.write(encodeClientCommand(command))
  }

  close(): void {
    this.keepAlive = false
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer)
    this.reconnectTimer = undefined
    this.ready = false
    this.socket?.destroy()
    this.socket = undefined
    this.buffer = ''
  }

  private consume(chunk: string, onHandshake: () => void): void {
    this.buffer += chunk
    let newline = this.buffer.indexOf('\n')
    while (newline >= 0) {
      const line = this.buffer.slice(0, newline)
      this.buffer = this.buffer.slice(newline + 1)
      if (line.trim()) {
        try {
          const event = decodeAgentEvent(line)
          if (event.type === 'hello_ack' && !this.ready) {
            this.ready = true
            this.keepAlive = true
            this.emit('status', { phase: 'connected', detail: `Connected to FatCat Agent ${event.agent_version}` })
            onHandshake()
          }
          this.emit('event', event as AgentEvent)
        } catch {
          this.emit('diagnostic', 'Agent sent an invalid protocol event.')
        }
      }
      newline = this.buffer.indexOf('\n')
    }
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer) return
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = undefined
      void this.connect().catch(() => {
        if (this.keepAlive) this.scheduleReconnect()
      })
    }, this.reconnectDelayMs)
    this.reconnectTimer.unref()
  }
}
