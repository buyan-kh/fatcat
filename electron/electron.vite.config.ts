import path from 'node:path'
import { defineConfig, externalizeDepsPlugin } from 'electron-vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const source = path.resolve('src')

export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
    resolve: { alias: { '@main': path.join(source, 'main'), '@shared': path.join(source, 'shared') } },
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
    resolve: { alias: { '@shared': path.join(source, 'shared') } },
  },
  renderer: {
    root: '.',
    resolve: {
      alias: {
        '@renderer': path.join(source, 'renderer/src'),
        '@shared': path.join(source, 'shared'),
      },
    },
    plugins: [react(), tailwindcss()],
  },
})
