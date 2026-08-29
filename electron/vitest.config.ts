import path from 'node:path'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

const source = path.resolve('src')

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@renderer': path.join(source, 'renderer/src'),
      '@shared': path.join(source, 'shared'),
      '@main': path.join(source, 'main'),
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    restoreMocks: true,
  },
})
