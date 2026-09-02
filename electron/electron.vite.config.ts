import path from 'node:path'
import { defineConfig, externalizeDepsPlugin } from 'electron-vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const source = path.resolve('src')

export default defineConfig({
  main: {
    // The packaged app contains only the built output. Keep zod in the main
    // bundle so a copied Electron runtime does not fail before its window is
    // created looking for node_modules that are not shipped.
    plugins: [externalizeDepsPlugin({ exclude: ['zod'] })],
    resolve: { alias: { '@main': path.join(source, 'main'), '@shared': path.join(source, 'shared') } },
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
    resolve: { alias: { '@shared': path.join(source, 'shared') } },
    build: {
      rollupOptions: {
        output: { format: 'cjs', entryFileNames: '[name].cjs' },
      },
    },
  },
  renderer: {
    root: path.join(source, 'renderer'),
    resolve: {
      alias: {
        '@renderer': path.join(source, 'renderer/src'),
        '@shared': path.join(source, 'shared'),
      },
    },
    plugins: [react(), tailwindcss()],
  },
})
