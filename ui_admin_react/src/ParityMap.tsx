// Same data-loading logic as ui_admin/lib/presentation/screens/territories/territories_screen.dart,
// rendered with MapLibre (WebGL) instead of flutter_map (canvas).
import { useEffect, useRef, useState } from 'react'
import * as maplibregl from 'maplibre-gl'
import type { Map as MLMap } from 'maplibre-gl'
import { API, fetchBounds, fetchUnionList } from './api'
import { useAuth } from './store'

maplibregl.setWorkerUrl('/maplibre/maplibre-gl-worker.mjs')

const GRID = 0.15                 // _gridCellSize
const POLY_ZOOM = 10              // _polygonZoomThreshold
const MAX_PTS = 30                // _maxPointsPerPolygon
const COLORS = ['#2196F3', '#4CAF50', '#FF9800', '#9C27B0', '#E91E63', '#00BCD4', '#FF5722', '#3F51B5']

interface Terr { id: string; solid?: string; entity_name?: string; union_name?: string; city?: string; state?: string; geometry: any }
type Ring = [number, number][]

const firstRing = (g: any): Ring => {                         // _parseGeometry
  if (!g) return []
  if (g.type === 'Polygon') return g.coordinates[0]
  if (g.type === 'MultiPolygon') return g.coordinates[0][0]
  return []
}
const simplify = (pts: Ring, max: number): Ring => {          // _simplifyPolygon (every Nth point)
  if (pts.length <= max) return pts
  const step = Math.ceil(pts.length / max); const out: Ring = []
  for (let i = 0; i < pts.length; i += step) out.push(pts[i])
  if (out[out.length - 1] !== pts[pts.length - 1]) out.push(pts[pts.length - 1])
  return out
}
const centroid = (pts: Ring): [number, number] | null => {
  if (!pts.length) return null
  let x = 0, y = 0; for (const p of pts) { x += p[0]; y += p[1] }
  return [x / pts.length, y / pts.length]
}
const fromFeature = (f: any): Terr => ({ ...(f.properties ?? {}), id: f.id ?? f.properties?.id, geometry: f.geometry ?? f.properties?.geometry })

declare global { interface Window { __map?: MLMap; __stats?: { requests: { url: string; ms: number; bytes: number }[] } } }

export default function ParityMap({ unionNames, selected }: { unionNames: string[]; selected: { name: string; n: number } | null }) {
  const el = useRef<HTMLDivElement>(null)
  const map = useRef<MLMap | null>(null)
  const cache = useRef(new Map<string, Terr>())
  const cells = useRef(new Set<string>())
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const names = useRef(unionNames); names.current = unionNames
  const [zoom, setZoom] = useState(10)
  const [counts, setCounts] = useState({ loaded: 0, cells: 0 })
  const [busy, setBusy] = useState(false)

  const colorOf = (u?: string) => { const i = names.current.indexOf(u ?? ''); return COLORS[i >= 0 ? i % COLORS.length : 0] }

  const render = () => {                                       // _buildPolygons + _buildMarkers
    const m = map.current; if (!m) return
    const polys: any[] = [], pts: any[] = []
    for (const t of cache.current.values()) {
      const ring = firstRing(t.geometry); if (!ring.length) continue
      const color = colorOf(t.union_name)
      polys.push({ type: 'Feature', properties: { color }, geometry: { type: 'Polygon', coordinates: [simplify(ring, MAX_PTS)] } })
      const c = centroid(ring); if (c) pts.push({ type: 'Feature', properties: { color, id: t.id, name: t.entity_name, union: t.union_name, solid: t.solid }, geometry: { type: 'Point', coordinates: c } })
    }
    ;(m.getSource('polys') as maplibregl.GeoJSONSource)?.setData({ type: 'FeatureCollection', features: polys })
    ;(m.getSource('pts') as maplibregl.GeoJSONSource)?.setData({ type: 'FeatureCollection', features: pts })
    setCounts({ loaded: cache.current.size, cells: cells.current.size })
  }

  const loadInBounds = async () => {                           // _loadTerritoriesInBounds
    const m = map.current; if (!m) return
    const b = m.getBounds(); const [w, s, e, n] = [b.getWest(), b.getSouth(), b.getEast(), b.getNorth()]
    const need: string[] = []
    for (let la = Math.floor(s / GRID); la <= Math.floor(n / GRID); la++)
      for (let lo = Math.floor(w / GRID); lo <= Math.floor(e / GRID); lo++) { const k = `${la},${lo}`; if (!cells.current.has(k)) need.push(k) }
    render()
    if (!need.length) return
    setBusy(true)
    try {
      const d = await fetchBounds([w, s, e, n], m.getZoom(), 30)
      const list = d.features ? d.features.map(fromFeature) : (d.territories ?? []).map((x: any) => x as Terr)
      for (const t of list) if (t.id) cache.current.set(t.id, t)
      need.forEach((k) => cells.current.add(k))
      render()
    } finally { setBusy(false) }
  }

  useEffect(() => {
    const m = new maplibregl.Map({
      container: el.current!, center: [-74.006, 40.7128], zoom: 10,     // New York default, like Flutter
      style: { version: 8,
        sources: { base: { type: 'raster', tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'], tileSize: 256, attribution: '© OpenStreetMap contributors' } },
        layers: [{ id: 'base', type: 'raster', source: 'base' }] },
      transformRequest: (url: string) => url.startsWith(API) ? { url, headers: { Authorization: `Bearer ${useAuth.getState().token}` } } : { url },
    })
    map.current = m; window.__map = m
    m.addControl(new maplibregl.NavigationControl(), 'top-left')
    m.on('load', () => {
      const empty = { type: 'FeatureCollection', features: [] } as any
      m.addSource('polys', { type: 'geojson', data: empty }); m.addSource('pts', { type: 'geojson', data: empty })
      m.addLayer({ id: 'poly-fill', type: 'fill', source: 'polys', minzoom: POLY_ZOOM, paint: { 'fill-color': ['get', 'color'], 'fill-opacity': 100 / 255 } })
      m.addLayer({ id: 'poly-line', type: 'line', source: 'polys', minzoom: POLY_ZOOM, paint: { 'line-color': ['get', 'color'], 'line-width': 2 } })
      m.addLayer({ id: 'pts', type: 'circle', source: 'pts', paint: {
        'circle-color': ['get', 'color'], 'circle-stroke-color': '#fff',
        'circle-radius': ['step', ['zoom'], 10, POLY_ZOOM, 4], 'circle-stroke-width': ['step', ['zoom'], 2, POLY_ZOOM, 1] } })
      m.on('click', 'pts', (ev: maplibregl.MapMouseEvent & { features?: maplibregl.MapGeoJSONFeature[] }) => {
        const f = ev.features?.[0]; if (!f) return; const p = f.properties as Record<string, string>
        const c = (f.geometry as any).coordinates as [number, number]
        if (m.getZoom() < POLY_ZOOM) m.easeTo({ center: c, zoom: POLY_ZOOM + 2 })
        new maplibregl.Popup().setLngLat(c).setHTML(`<b>${p.name}</b><br>${p.union}<br>SOLID ${p.solid}`).addTo(m)
      })
      m.on('mouseenter', 'pts', () => (m.getCanvas().style.cursor = 'pointer')); m.on('mouseleave', 'pts', () => (m.getCanvas().style.cursor = ''))
      setTimeout(loadInBounds, 300)                             // Flutter: onMapReady → delayed load
    })
    m.on('move', () => {
      setZoom(m.getZoom()); clearTimeout(timer.current); timer.current = setTimeout(loadInBounds, 200)
    })
    return () => m.remove()
  }, [])

  useEffect(() => { render() }, [unionNames.join('|')])

  useEffect(() => {                                             // _loadUnionTerritories + _fitMapToTerritories
    if (!selected) return
    ;(async () => {
      const m = map.current; if (!m) return
      setBusy(true)
      try {
        const d = await fetchUnionList(selected.name)
        const list: Terr[] = (d.territories ?? []).map((x: any) => x)
        for (const t of list) cache.current.set(t.id, t)
        render()
        const b = new maplibregl.LngLatBounds(); let any = false
        for (const t of list) for (const c of firstRing(t.geometry)) { if (Math.abs(c[0]) < 0.1 && Math.abs(c[1]) < 0.1) continue; b.extend(c as [number, number]); any = true }
        if (any) m.fitBounds(b, { padding: 50, animate: false })  // flutter fitCamera jumps
      } finally { setBusy(false) }
    })()
  }, [selected?.n])

  return (<div className="mapwrap">
    <div ref={el} className="map" />
    {busy && <div className="busy">Loading…</div>}
    <div className="info"><b>{counts.loaded} territories loaded</b><small>{counts.cells} areas cached · Zoom {Math.round(zoom)}</small></div>
  </div>)
}
