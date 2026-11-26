import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { fetchUnionStats, searchTerritories, searchTerritoriesFlutter, fetchAllocations, fetchTeamLeaders } from './api'
import { useAuth } from './store'
import MapView from './MapView'
import ParityMap from './ParityMap'

// ?mode=tiles -> vector tiles (new). default 'parity' -> same API logic as the Flutter admin.
const MODE = new URLSearchParams(location.search).get('mode') === 'tiles' ? 'tiles' : 'parity'

export default function Territories() {
  const { email, logout } = useAuth()
  const [union, setUnion] = useState<string>('')
  const [q, setQ] = useState('')
  const [sel, setSel] = useState<{ name: string; n: number } | null>(null)
  const pick = (name: string) => { setUnion(name); if (MODE === 'parity' && name) setSel({ name, n: Date.now() }) }
  useQuery({ queryKey: ['alloc'], queryFn: fetchAllocations })      // Flutter loads these on entry too
  useQuery({ queryKey: ['leaders'], queryFn: fetchTeamLeaders })
  const stats = useQuery({ queryKey: ['unionStats'], queryFn: fetchUnionStats })
  const search = useQuery({ queryKey: ['search', q], queryFn: () => (MODE === 'tiles' ? searchTerritories(q) : searchTerritoriesFlutter(q)), enabled: q.length >= 3 })
  const total = stats.data?.unions.reduce((a, u) => a + u.territory_count, 0) ?? 0

  return (
    <div className="shell">
      <header><b>Territory Management</b><span>{email} · <a onClick={logout}>Sign out</a></span></header>
      <div className="body">
        {MODE === 'tiles' ? <MapView union={union} /> : <ParityMap unionNames={stats.data?.unions.map((u) => u.union_name) ?? []} selected={sel} />}
        <aside>
          <h2>Territory Statistics</h2>
          {stats.isLoading && <p>Loading…</p>}
          {stats.isError && <p className="err">Failed to load statistics</p>}
          {stats.data && (<>
            <div className="tiles"><div><b>{stats.data.unions.length}</b>Unions</div><div><b>{(total / 1000).toFixed(1)}K</b>Territories</div></div>
            <select value={union} onChange={(e) => pick(e.target.value)}>
              <option value="">All unions</option>
              {stats.data.unions.map((u) => <option key={u.union_name}>{u.union_name}</option>)}
            </select>
            <ul>{stats.data.unions.map((u) => (
              <li key={u.union_name} onClick={() => pick(u.union_name)}>
                <span>{u.union_name}<small>{u.territory_count.toLocaleString()} territories</small></span>
                <em>{(u.total_housing / 1e6).toFixed(1)}M homes</em>
              </li>))}</ul>
          </>)}
          <input className="search" placeholder="Search territories (3+ chars)…" value={q} onChange={(e) => setQ(e.target.value)} />
          {search.isFetching && <p>Searching…</p>}
          <ul>{search.data?.territories.map((t) => (
            <li key={t.id}><span>{t.entity_name}<small>{[t.city, t.state].filter(Boolean).join(', ')}</small></span></li>))}</ul>
        </aside>
      </div>
    </div>
  )
}
