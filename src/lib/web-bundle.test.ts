import { readFileSync } from 'node:fs'
import { dirname } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { describe, expect, it } from 'vitest'

const webAppDirectory = fileURLToPath(
  new URL('../../macos/FatCat/Sources/FatCat/Resources/FatCatAvatar/', import.meta.url),
)
const bundledAvatarURL = pathToFileURL(`${webAppDirectory}/avatar.html`)

describe('bundled WKWebView avatar surface', () => {
  it('uses relative JS and CSS asset URLs that resolve inside the bundled avatar directory', () => {
    const indexHTML = readFileSync(fileURLToPath(bundledAvatarURL), 'utf8')
    const assetReferences = [...indexHTML.matchAll(/(?:src|href)="([^"]+\.(?:js|css))"/g)].map(
      (match) => match[1],
    )

    expect(assetReferences).toEqual(expect.arrayContaining([
      expect.stringMatching(/\.js$/),
      expect.stringMatching(/\.css$/),
    ]))

    for (const reference of assetReferences) {
      expect(reference.startsWith('/')).toBe(false)

      const assetURL = new URL(reference, bundledAvatarURL)
      expect(dirname(fileURLToPath(assetURL))).toBe(webAppDirectory + 'assets')
      expect(readFileSync(fileURLToPath(assetURL)).byteLength).toBeGreaterThan(0)
    }
  })
})
