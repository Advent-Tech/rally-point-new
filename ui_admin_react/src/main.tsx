import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import 'maplibre-gl/dist/maplibre-gl.css'
import './index.css'
import App from './App'

const qc = new QueryClient({ defaultOptions: { queries: { staleTime: 5 * 60_000, retry: 1 } } })
createRoot(document.getElementById('root')!).render(
  <StrictMode><QueryClientProvider client={qc}><App /></QueryClientProvider></StrictMode>,
)
