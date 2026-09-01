import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import App from './App'

describe('FatCat Electron shell', () => {
  it('renders the application identity', () => {
    render(<App />)
    expect(screen.getByRole('heading', { name: 'FatCat' })).toBeInTheDocument()
  })
})
