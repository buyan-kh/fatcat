import { EventEmitter } from 'node:events'
import { createConnection, type Socket } from 'node:net'
import { decodeAgentEvent, encodeClientCommand, type AgentEvent, type ClientCommand } from '../../shared/protocol'

type SocketTransportOptions = {
  handshakeTimeoutMs?: number
  reconnectDelayMs?: number
  reconnectAttempts?: number
}

export class SocketTransport extends EventEmitter {
  private socket?: Socket
  private buffer = ''
  private ready = false
  private connecting?: Promise<void>
  private readonly handshakeTimeoutMs: number
  private readonly reconnectDelayMs: number
  private readonly maximumReconnectAttempts: number
  private reconnectTimer?: NodeJS.Timeout
  private reconnectAttempt = 0
  private keepAlive = false

  constructor(readonly socketPath: string, options: SocketTransportOptions = {}) {
    super()
    this.handshakeTimeoutMs = options.handshakeTimeoutMs ?? 3000
    this.reconnectDelayMs = options.reconnectDelayMs ?? 500
    this.maximumReconnectAttempts = options.reconnectAttempts ?? 8
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
    if (!this.keepAlive) this.reconnectAttempt = 0
    this.buffer = ''
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
        if (this.socket === socket) {
          this.ready = false
          this.socket = undefined
          this.buffer = ''
          socket.destroy()
        }
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
        this.buffer = ''
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
          if ('type' in event && event.type === 'hello_ack' && !this.ready) {
            this.ready = true
            this.keepAlive = true
            this.reconnectAttempt = 0
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
    if (this.reconnectTimer || !this.keepAlive) return
    if (this.reconnectAttempt >= this.maximumReconnectAttempts) {
      this.keepAlive = false
      this.emit('status', { phase: 'failed', detail: 'FatCat Agent did not reconnect.' })
      return
    }
    const delay = Math.min(8000, this.reconnectDelayMs * (2 ** this.reconnectAttempt))
    this.reconnectAttempt += 1
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = undefined
      void this.connect().catch(() => {
        if (this.keepAlive) this.scheduleReconnect()
      })
    }, delay)
    this.reconnectTimer.unref()
  }
}
