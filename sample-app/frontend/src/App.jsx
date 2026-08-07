import { useEffect, useState } from 'react'

export default function App() {
  const [history, setHistory] = useState([])
  const [error, setError] = useState(null)

  const [user, setUser] = useState(null)
  const [authMode, setAuthMode] = useState('login')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [authError, setAuthError] = useState(null)
  const [authMessage, setAuthMessage] = useState(null)

  const fetchHistory = () => {
    fetch('/api/history')
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        return res.json()
      })
      .then(setHistory)
      .catch((err) => setError(err.message))
  }

  useEffect(() => {
    fetchHistory()
  }, [])

  const switchMode = (mode) => {
    setAuthMode(mode)
    setAuthError(null)
    setAuthMessage(null)
  }

  const handleRegister = (e) => {
    e.preventDefault()
    setAuthError(null)
    setAuthMessage(null)
    fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    })
      .then(async (res) => {
        if (res.status === 201) {
          setAuthMessage('Registered. You can log in now.')
          setAuthMode('login')
          setPassword('')
          return
        }
        if (res.status === 409) throw new Error('email already registered')
        const text = await res.text()
        throw new Error(text || `HTTP ${res.status}`)
      })
      .catch((err) => setAuthError(err.message))
  }

  const handleLogin = (e) => {
    e.preventDefault()
    setAuthError(null)
    setAuthMessage(null)
    fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    })
      .then(async (res) => {
        if (res.ok) {
          const data = await res.json()
          setUser(data.email)
          setPassword('')
          return
        }
        const text = await res.text()
        throw new Error(text || 'invalid credentials')
      })
      .catch((err) => setAuthError(err.message))
  }

  const handleLogout = () => {
    fetch('/api/logout', { method: 'POST' }).finally(() => {
      setUser(null)
      setEmail('')
      setPassword('')
      setAuthError(null)
      setAuthMessage(null)
    })
  }

  return (
    <div style={{ fontFamily: 'sans-serif', margin: '2rem' }}>
      <h1>Server Sorcery 101</h1>

      <div style={{ marginBottom: '2rem', paddingBottom: '1rem', borderBottom: '1px solid #ccc' }}>
        {user ? (
          <div>
            <p>Logged in as {user}</p>
            <button onClick={handleLogout}>Logout</button>
          </div>
        ) : (
          <div>
            <div style={{ marginBottom: '0.5rem' }}>
              <button onClick={() => switchMode('login')} disabled={authMode === 'login'}>
                Login
              </button>{' '}
              <button onClick={() => switchMode('register')} disabled={authMode === 'register'}>
                Register
              </button>
            </div>
            <form onSubmit={authMode === 'login' ? handleLogin : handleRegister}>
              <div>
                <input
                  type="email"
                  placeholder="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>
              <div>
                <input
                  type="password"
                  placeholder="password (min 8 chars)"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  minLength={8}
                  required
                />
              </div>
              <button type="submit">{authMode === 'login' ? 'Log in' : 'Register'}</button>
            </form>
            {authError && <p style={{ color: 'red' }}>Error: {authError}</p>}
            {authMessage && <p style={{ color: 'green' }}>{authMessage}</p>}
          </div>
        )}
      </div>

      <button onClick={fetchHistory}>Refresh</button>
      {error && <p style={{ color: 'red' }}>Error: {error}</p>}
      <table border="1" cellPadding="6" style={{ marginTop: '1rem' }}>
        <thead>
          <tr>
            <th>ID</th>
            <th>Recorded At</th>
            <th>Alloc Bytes</th>
            <th>Goroutines</th>
          </tr>
        </thead>
        <tbody>
          {history.map((h) => (
            <tr key={h.id}>
              <td>{h.id}</td>
              <td>{h.recorded_at}</td>
              <td>{h.alloc_bytes}</td>
              <td>{h.num_goroutine}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
