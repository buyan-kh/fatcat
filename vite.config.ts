import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    react(),
    {
      name: 'browser-safe-avatar-core-schema',
      enforce: 'post',
      transform(code, id) {
        if (!id.endsWith('/@bible-strong/avatar-core/dist/index.js')) return undefined
        return code
          .replace('$schema: "https://json-schema.org/draft/2020-12/schema",', '')
          .replace(/new O\(\{\s*allErrors:\s*!0,\s*strict:\s*!0\s*\}\)/, 'new O({allErrors:!0,strict:false})')
      },
    },
  ],
  base: './',
  test: {
    exclude: ['**/node_modules/**', '**/.build/**', '**/vendor/**', '.worktrees/**', 'electron/**'],
  },
})
