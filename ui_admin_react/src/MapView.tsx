import { useEffect, useRef } from 'react'
import * as maplibregl from 'maplibre-gl'
import type { Map as MLMap } from 'maplibre-gl'
import { API } from './api'
import { useAuth } from './store'

// Serve the ESM worker as a static asset (bundlers can't inline it reliably)
maplibregl.setWorkerUrl('/maplibre/maplibre-gl-worker.mjs')

const UNION_COLORS: Record<string, string> = { 'Lake Union': '#1e88e5', 'Pacific Union': '#43a047' }

declare global { interface Window { __map?: MLMap; __perf: { tiles: { url: string; ms: number; bytes: number; status: number }[]; idleAt: number[] } } }
window.__perf = { tiles: [], idleAt: [] }

export default function MapView({ union }: { union: string }) {
  const el = useRef<HTMLDivElement>(null)
  const map = useRef<MLMap | null>(null)

  useEffect(() => {
    const m = new maplibregl.Map({
      container: el.current!,
      center: [-112.2, 33.6], zoom: 6,
      style: {
        version: 8,
        sources: { base: { type: 'raster', tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'], tileSize: 256, attribution: '© OpenStreetMap contributors' } },
        layers: [{ id: 'base', type: 'raster', source: 'base' }],
      },
      // Tiles sit behind the gateway's auth: attach the bearer token + record timings.
      transformRequest: (url: string) => url.startsWith(API)
        ? { url, headers: { Authorization: `Bearer ${useAuth.getState().token}` } } : { url },
    })
    map.current = m; window.__map = m
    m.addControl(new maplibregl.NavigationControl(), 'top-left')

    m.on('load', () => {
      m.addSource('territories', { type: 'vector', tiles: [`${API}/api/geo/tiles/{z}/{x}/{y}`], minzoom: 5, maxzoom: 14 })
      m.addLayer({ id: 'terr-fill', type: 'fill', source: 'territories', 'source-layer': 'territories',
        paint: { 'fill-color': ['match', ['get', 'union_name'], 'Lake Union', UNION_COLORS['Lake Union'], 'Pacific Union', UNION_COLORS['Pacific Union'], '#888'], 'fill-opacity': 0.35 } })
      m.addLayer({ id: 'terr-line', type: 'line', source: 'territories', 'source-layer': 'territories', minzoom: 8,
        paint: { 'line-color': '#1b5e20', 'line-width': 0.8 } })
      m.addLayer({ id: 'terr-label', type: 'symbol', source: 'territories', 'source-layer': 'territories', minzoom: 14,
        layout: { 'text-field': ['get', 'entity_name'], 'text-size': 11 }, paint: { 'text-halo-color': '#fff', 'text-halo-width': 1 } })
    })
    m.on('idle', () => window.__perf.idleAt.push(performance.now()))
    m.on('click', 'terr-fill', (e: maplibregl.MapMouseEvent & { features?: maplibregl.MapGeoJSONFeature[] }) => {
      const f = e.features?.[0]; if (!f) return
      const p = f.properties as Record<string, string>
      new maplibregl.Popup().setLngLat(e.lngLat)
        .setHTML(`<b>${p.entity_name}</b><br>${p.city ?? ''} ${p.state ?? ''}<br>${p.union_name} · ${p.conference ?? ''}<br>SOLID ${p.solid} · pop ${p.population ?? '-'}`).addTo(m)
    })
    m.on('mouseenter', 'terr-fill', () => (m.getCanvas().style.cursor = 'pointer'))
    m.on('mouseleave', 'terr-fill', () => (m.getCanvas().style.cursor = ''))
    return () => m.remove()
  }, [])

  // Union filter is applied on the GPU: no refetch needed.
  useEffect(() => {
    const m = map.current; if (!m) return
    const apply = () => ['terr-fill', 'terr-line', 'terr-label'].forEach((id) => m.getLayer(id) && m.setFilter(id, union ? ['==', ['get', 'union_name'], union] : null))
    if (m.isStyleLoaded()) apply(); else m.once('idle', apply)
  }, [union])

  return <div ref={el} className="map" />
}
