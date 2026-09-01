import { contextBridge, ipcRenderer } from 'electron'
import {
  FATCAT_EVENT_CHANNEL,
  FATCAT_INVOKE_CHANNELS,
  type FatCatAPI,
  type FatCatEvent,
} from '../shared/api'
import type { AppearancePreference } from '../shared/chat'

const api: FatCatAPI = {
  snapshot: () => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.snapshot),
  createConversation: (workspacePath) => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.createConversation, workspacePath),
  selectConversation: (id) => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.selectConversation, id),
  renameConversation: (id, title) => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.renameConversation, id, title),
  deleteConversation: (id) => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.deleteConversation, id),
  sendMessage: (text) => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.sendMessage, text),
  cancelTurn: () => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.cancelTurn),
  retryLastTurn: () => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.retryLastTurn),
  chooseWorkspace: () => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.chooseWorkspace),
  setAppearance: (appearance: AppearancePreference) => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.setAppearance, appearance),
  restartAgent: () => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.restartAgent),
  getDiagnostics: () => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.getDiagnostics),
  minimizeWindow: () => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.minimizeWindow),
  toggleMaximizeWindow: () => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.toggleMaximizeWindow),
  isWindowMaximized: () => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.isWindowMaximized),
  closeWindow: () => ipcRenderer.invoke(FATCAT_INVOKE_CHANNELS.closeWindow),
  subscribe: (listener) => {
    const handler = (_event: Electron.IpcRendererEvent, payload: FatCatEvent) => listener(payload)
    ipcRenderer.on(FATCAT_EVENT_CHANNEL, handler)
    return () => ipcRenderer.removeListener(FATCAT_EVENT_CHANNEL, handler)
  },
}

contextBridge.exposeInMainWorld('fatcat', api)
