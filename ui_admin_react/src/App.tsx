import { useState } from 'react'
import { useAuth } from './store'
import { login } from './api'
import Territories from './Territories'

function Login() {
  const setSession = useAuth((s) => s.setSession)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)
  return (
    <form className="login" onSubmit={async (e) => {
      e.preventDefault(); setBusy(true); setErr('')
      try { const d = await login(email, password); setSession(d.access_token, d.user.email) }
      catch (x) { setErr((x as Error).message) } finally { setBusy(false) }
    }}>
      <h1>Admin Panel</h1>
      <p>Sign in to access the admin panel</p>
      <input placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)} />
      <input placeholder="Password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
      <button disabled={busy}>{busy ? 'Signing in…' : 'Sign In'}</button>
      {err && <div className="err">{err}</div>}
      <div className="note">Only Admin and Superadmin accounts can access this panel.</div>
    </form>
  )
}

export default function App() {
  const token = useAuth((s) => s.token)
  return token ? <Territories /> : <Login />
}
