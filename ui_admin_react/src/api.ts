import { useAuth } from './store'

export const API = import.meta.env.VITE_API_URL ?? 'http://localhost:8080'

export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = useAuth.getState().token
  const res = await fetch(API + path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  })
  if (res.status === 401) useAuth.getState().logout()
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`)
  return res.json() as Promise<T>
}

export interface UnionStat { union_name: string; territory_count: number; church_count: number; conference_count: number; total_population: number; total_housing: number }
export interface TerritoryRow { id: string; solid: string; entity_name: string; city?: string; state?: string; union_name?: string; conference?: string; population?: number }

export const fetchUnionStats = () => api<{ unions: UnionStat[] }>('/api/geo/stats/unions')
export const searchTerritories = (q: string) =>
  api<{ territories: TerritoryRow[] }>(`/api/geo/territories/search?q=${encodeURIComponent(q)}&limit=25`)
export const fetchUnionBounds = (union: string) =>
  api<{ bounds?: [number, number, number, number] }>(`/api/geo/territories/list?union=${encodeURIComponent(union)}&limit=1&include_geometry=true`)

export async function login(email: string, password: string) {
  const d = await api<{ access_token: string; user: { display_name: string; role: string; email: string } }>(
    '/api/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) })
  if (!['admin', 'superadmin'].includes(d.user.role)) throw new Error('Only Admin and Superadmin accounts can access this panel.')
  return d
}

// ---- Same endpoints/params the Flutter admin uses (territories_screen.dart) ----
export const fetchAllocations = () => api<unknown>('/api/admin/territories/allocations')
export const fetchTeamLeaders = () => api<unknown>('/api/admin/team-leaders')
export interface GeoFeature { id: string; geometry: any; properties: Record<string, any> }
export const fetchBounds = (b: [number, number, number, number], zoom: number, limit = 30) =>
  api<{ features?: GeoFeature[]; territories?: any[] }>(
    `/api/geo/territories?bounds=${b.map((n) => n.toFixed(4)).join(',')}&limit=${limit}&zoom=${Math.round(zoom)}`)
export const fetchUnionList = (union: string) =>
  api<{ territories?: any[] }>(`/api/geo/territories/list?union=${encodeURIComponent(union)}&limit=50&include_geometry=true`)
export const searchTerritoriesFlutter = (q: string) =>
  api<{ territories: TerritoryRow[] }>(`/api/geo/territories/search?q=${encodeURIComponent(q)}&limit=50`)
