import { EventEmitter } from 'node:events'
import { existsSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { app, BrowserWindow, dialog, ipcMain, nativeTheme, screen, shell } from 'electron'
import { AgentSupervisor } from './agent/agent-supervisor'
import { FatCatService } from './agent/fatcat-service'
import { ConversationRepository } from './persistence/conversations'
import { WindowStateStore, type DisplayBounds } from './window-state'
import { FATCAT_EVENT_CHANNEL, FATCAT_INVOKE_CHANNELS } from '../shared/api'
import type { AppearancePreference } from '../shared/chat'
import type { ClientCommand } from '../shared/protocol'

class OfflineTransport extends EventEmitter {
  readonly isConnected = false
  send(_command: ClientCommand): void { throw new Error('FatCat Agent is not connected') }
}

let mainWindow: BrowserWindow | null = null
let supervisor: AgentSupervisor | null = null
let service: FatCatService | null = null
let windowState: WindowStateStore | null = null
let quitting = false

async function bootstrap(): Promise<void> {
  const userData = app.getPath('userData')
  const agentPath = resolveAgentPath()
  supervisor = new AgentSupervisor({
    agentPath,
    socketPath: join(userData, 'runtime', 'fatcat-electron-agent.sock'),
    hermesHome: process.env.FATCAT_HERMES_PATH || join(userData, 'Hermes'),
  })
  const repository = await ConversationRepository.open(join(userData, 'conversations.json'))
  windowState = await WindowStateStore.open(join(userData, 'window.json'))

  let transport
  let startupError: string | null = null
  try {
    transport = await supervisor.start()
  } catch (error) {
    startupError = errorMessage(error)
    transport = new OfflineTransport()
  }

  service = new FatCatService({
    repository,
    transport,
    defaultWorkspace: app.isPackaged ? process.env.HOME : resolve(app.getAppPath(), '..'),
    chooseWorkspace: async () => {
      const options: Electron.OpenDialogOptions = { properties: ['openDirectory', 'createDirectory'] }
      const result = mainWindow
        ? await dialog.showOpenDialog(mainWindow, options)
        : await dialog.showOpenDialog(options)
      return result.canceled ? null : result.filePaths[0] ?? null
    },
    diagnostics: async () => supervisor!.getDiagnostics(),
    restartAgent: async () => supervisor!.restart(),
  })
  service.on('event', (event) => mainWindow?.webContents.send(FATCAT_EVENT_CHANNEL, event))
  if (startupError) {
    queueMicrotask(() => transport.emit('status', { phase: 'failed', detail: startupError }))
  }

  registerIpc(service)
  await createWindow()
}

async function createWindow(): Promise<void> {
  const displays: DisplayBounds[] = screen.getAllDisplays().map((display) => display.workArea)
  const bounds = windowState?.resolve(displays) ?? { width: 1180, height: 760 }
  mainWindow = new BrowserWindow({
    ...bounds,
    minWidth: 900,
    minHeight: 620,
    show: false,
    backgroundColor: nativeTheme.shouldUseDarkColors ? '#1c1c1c' : '#fafafa',
    title: 'FatCat',
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 14, y: 14 },
    webPreferences: {
      preload: join(__dirname, '../preload/index.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  })

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (isSafeExternalUrl(url)) void shell.openExternal(url)
    return { action: 'deny' }
  })
  mainWindow.webContents.on('will-navigate', (event, url) => {
    const current = mainWindow?.webContents.getURL()
    if (url !== current) {
      event.preventDefault()
      if (isSafeExternalUrl(url)) void shell.openExternal(url)
    }
  })
  mainWindow.once('ready-to-show', () => mainWindow?.show())
  mainWindow.on('close', (event) => {
    if (!quitting && process.platform === 'darwin') {
      event.preventDefault()
      mainWindow?.hide()
      return
    }
    if (mainWindow && !mainWindow.isMaximized() && !mainWindow.isFullScreen()) void windowState?.save(mainWindow.getBounds())
  })
  mainWindow.on('closed', () => { mainWindow = null })

  if (process.env.ELECTRON_RENDERER_URL) await mainWindow.loadURL(process.env.ELECTRON_RENDERER_URL)
  else await mainWindow.loadFile(join(__dirname, '../renderer/index.html'))
}

function registerIpc(fatcat: FatCatService): void {
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.snapshot, () => fatcat.snapshot())
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.createConversation, (_event, workspacePath?: string) => fatcat.createConversation(workspacePath))
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.selectConversation, (_event, id: string) => fatcat.selectConversation(id))
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.renameConversation, (_event, id: string, title: string) => fatcat.renameConversation(id, title))
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.deleteConversation, (_event, id: string) => fatcat.deleteConversation(id))
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.sendMessage, (_event, text: string) => fatcat.sendMessage(text))
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.cancelTurn, () => fatcat.cancelTurn())
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.retryLastTurn, () => fatcat.retryLastTurn())
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.chooseWorkspace, () => fatcat.chooseWorkspace())
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.setAppearance, async (_event, appearance: AppearancePreference) => {
    nativeTheme.themeSource = appearance
    await fatcat.setAppearance(appearance)
  })
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.restartAgent, () => fatcat.restartAgent())
  ipcMain.handle(FATCAT_INVOKE_CHANNELS.getDiagnostics, () => fatcat.getDiagnostics())
}

export function isSafeExternalUrl(value: string): boolean {
  try {
    const url = new URL(value)
    return url.protocol === 'https:' || url.protocol === 'http:'
  } catch {
    return false
  }
}

function resolveAgentPath(): string {
  if (process.env.FATCAT_AGENT_PATH) return process.env.FATCAT_AGENT_PATH
  const candidates = app.isPackaged
    ? [join(process.resourcesPath, 'PeppaAgent', 'PeppaAgent')]
    : [resolve(app.getAppPath(), '..', 'agent', 'peppa_agent', 'PeppaAgent')]
  return candidates.find(existsSync) ?? candidates[0]!
}

app.whenReady().then(bootstrap).catch((error) => {
  dialog.showErrorBox('FatCat could not start', errorMessage(error))
})

app.on('activate', () => {
  if (mainWindow) mainWindow.show()
  else void createWindow()
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})

app.on('before-quit', (event) => {
  if (quitting) return
  event.preventDefault()
  quitting = true
  void supervisor?.stop().finally(() => app.quit())
})

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}
