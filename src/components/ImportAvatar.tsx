import { useRef, useState } from 'react'
import type { AvatarDefinition } from '@bible-strong/avatar-core'
import { normalizeImportedDefinition } from '../lib/avatar-data'

type ImportAvatarProps = {
  onImport: (definition: Readonly<AvatarDefinition>) => void
  onError: (message: string) => void
}

export function ImportAvatar({ onImport, onError }: ImportAvatarProps) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [isReading, setIsReading] = useState(false)

  async function handleFile(file: File | undefined) {
    if (!file) return
    setIsReading(true)
    try {
      const result = normalizeImportedDefinition(await file.text())
      if (result.ok) {
        onImport(result.definition)
        onError('')
      } else {
        onError(result.message)
      }
    } catch {
      onError('That file could not be read. Choose a UTF-8 JSON avatar definition.')
    } finally {
      setIsReading(false)
      if (inputRef.current) inputRef.current.value = ''
    }
  }

  return (
    <div className="import-block">
      <input
        ref={inputRef}
        className="visually-hidden"
        type="file"
        accept=".json,.avatar.json,application/json"
        aria-label="Import an avatar definition JSON file"
        onChange={(event) => void handleFile(event.target.files?.[0])}
      />
      <button className="button button-accent button-full" type="button" onClick={() => inputRef.current?.click()} disabled={isReading}>
        {isReading ? 'Reading definition…' : 'Import avatar JSON'}
      </button>
      <p className="helper-text">Drop in any valid Bible Strong definition to compare it here.</p>
    </div>
  )
}
