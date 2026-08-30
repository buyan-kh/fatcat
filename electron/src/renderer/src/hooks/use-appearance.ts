import { useEffect } from 'react'
import type { AppearancePreference } from '@shared/chat'

export function useAppearance(appearance?: AppearancePreference): void {
  useEffect(() => {
    if (!appearance) return
    const systemAppearance = window.matchMedia('(prefers-color-scheme: dark)')
    const apply = () => {
      const dark = appearance === 'dark' || (appearance === 'system' && systemAppearance.matches)
      document.documentElement.classList.toggle('dark', dark)
    }
    apply()
    if (appearance !== 'system') return
    systemAppearance.addEventListener('change', apply)
    return () => systemAppearance.removeEventListener('change', apply)
  }, [appearance])
}
