import { useEffect, useState } from 'react'

export default function App() {
  const [history, setHistory] = useState([])
  const [error, setError] = useState(null)

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

  return (
    <div style={{ fontFamily: 'sans-serif', margin: '2rem' }}>
      <h1>Server Sorcery 101</h1>
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
