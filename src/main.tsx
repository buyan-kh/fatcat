import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@bible-strong/avatar-react/styles.css'
import { App } from './App'
import { retireFatCatContent } from './lib/retirement'
import './styles.css'

if (typeof window !== 'undefined') retireFatCatContent(window.localStorage)

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
