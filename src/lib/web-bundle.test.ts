import { readFileSync } from 'node:fs'
import { dirname } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { describe, expect, it } from 'vitest'

const webAppDirectory = fileURLToPath(
  new URL('../../macos/PeppaAnywhere/Sources/PeppaAnywhere/Resources/WebApp/', import.meta.url),
)
const bundledIndexURL = pathToFileURL(`${webAppDirectory}/index.html`)

describe('bundled WKWebView web surface', () => {
  it('uses relative JS and CSS asset URLs that resolve inside the bundled WebApp directory', () => {
    const indexHTML = readFileSync(fileURLToPath(bundledIndexURL), 'utf8')
    const assetReferences = [...indexHTML.matchAll(/(?:src|href)="([^"]+\.(?:js|css))"/g)].map(
      (match) => match[1],
    )

    expect(assetReferences).toEqual(expect.arrayContaining([
      expect.stringMatching(/\.js$/),
      expect.stringMatching(/\.css$/),
    ]))

    for (const reference of assetReferences) {
      expect(reference.startsWith('/')).toBe(false)

      const assetURL = new URL(reference, bundledIndexURL)
      expect(dirname(fileURLToPath(assetURL))).toBe(webAppDirectory + 'assets')
      expect(readFileSync(fileURLToPath(assetURL)).byteLength).toBeGreaterThan(0)
    }
  })
})
