import { useState } from 'react'
import axios from 'axios'
import './Dashboard.css'

const getApiUrl = () => {
  if (typeof window !== 'undefined' && window.location.hostname.includes('azurestaticapps.net')) {
    return 'https://gait-analysis-api-simple.azurewebsites.net'
  }
  return (import.meta as any).env?.VITE_API_URL || 'http://localhost:8000'
}

const API_URL = getApiUrl()

interface OlderAdultReport {
  gait_health_score: {
    score: number
    out_of: number
    interpretation: string
  }
  simple_metrics: any
  message: string
}

export default function OlderAdultDashboard() {
  const [analysisId, setAnalysisId] = useState<string>('')
  const [report, setReport] = useState<OlderAdultReport | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const fetchReport = async () => {
    if (!analysisId) return

    setLoading(true)
    setError(null)

    try {
      const response = await axios.get(
        `${API_URL}/api/v1/reports/${analysisId}?audience=older_adult`
      )
      setReport(response.data)
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to fetch report')
    } finally {
      setLoading(false)
    }
  }

  const getScoreColor = (score: number) => {
    if (score >= 80) return '#27ae60'
    if (score >= 60) return '#f39c12'
    return '#e74c3c'
  }

  return (
    <div className="dashboard">
      <h1>Your Gait Health Summary</h1>
      <p className="subtitle">Simple, easy-to-understand information about your mobility</p>

      <div className="card">
        <h2>View Your Results</h2>
        <div className="input-group">
          <input
            type="text"
            placeholder="Enter Analysis ID"
            value={analysisId}
            onChange={(e) => setAnalysisId(e.target.value)}
            className="input"
          />
          <button onClick={fetchReport} disabled={loading} className="btn btn-primary">
            {loading ? 'Loading...' : 'View Results'}
          </button>
        </div>
        {error && <div className="error">{error}</div>}
      </div>

      {report && (
        <>
          <div className="card">
            <h2>Your Gait Health Score</h2>
            <div 
              className="score-display"
              style={{
                textAlign: 'center',
                padding: '2rem'
              }}
            >
              <div 
                style={{
                  fontSize: '4rem',
                  fontWeight: 'bold',
                  color: getScoreColor(report.gait_health_score.score),
                  marginBottom: '1rem'
                }}
              >
                {report.gait_health_score.score}
              </div>
              <div style={{ fontSize: '1.2rem', color: '#7f8c8d' }}>
                out of {report.gait_health_score.out_of}
              </div>
              <p style={{ marginTop: '1rem', fontSize: '1.1rem' }}>
                {report.gait_health_score.interpretation}
              </p>
            </div>
          </div>

          <div className="card">
            <h2>Your Walking Information</h2>
            <div className="metrics-grid">
              <div className="metric">
                <label>Walking Speed</label>
                <div className="value">
                  {report.simple_metrics?.walking_speed}
                </div>
              </div>
              <div className="metric">
                <label>Steps Per Minute</label>
                <div className="value">
                  {report.simple_metrics?.steps_per_minute}
                </div>
              </div>
            </div>
          </div>

          <div className="card">
            <h2>Message</h2>
            <p style={{ fontSize: '1.1rem', lineHeight: '1.6' }}>
              {report.message}
            </p>
          </div>
        </>
      )}
    </div>
  )
}

