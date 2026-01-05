import { useState } from 'react'
import axios from 'axios'
import './Dashboard.css'

const API_URL = (import.meta as any).env?.VITE_API_URL || 'http://localhost:8000'

interface CaregiverReport {
  fall_risk: {
    level: string
    color: string
    description: string
  }
  key_metrics: any
  trends: any
  recommendations: string[]
}

export default function CaregiverDashboard() {
  const [analysisId, setAnalysisId] = useState<string>('')
  const [report, setReport] = useState<CaregiverReport | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const fetchReport = async () => {
    if (!analysisId) return

    setLoading(true)
    setError(null)

    try {
      const response = await axios.get(
        `${API_URL}/api/v1/reports/${analysisId}?audience=caregiver`
      )
      setReport(response.data)
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to fetch report')
    } finally {
      setLoading(false)
    }
  }

  const getRiskColor = (level: string) => {
    switch (level) {
      case 'high': return '#e74c3c'
      case 'moderate': return '#f39c12'
      case 'low': return '#27ae60'
      default: return '#95a5a6'
    }
  }

  return (
    <div className="dashboard">
      <h1>Caregiver Monitoring Dashboard</h1>
      <p className="subtitle">Simple, actionable insights with trend tracking</p>

      <div className="card">
        <h2>Retrieve Analysis Report</h2>
        <div className="input-group">
          <input
            type="text"
            placeholder="Enter Analysis ID"
            value={analysisId}
            onChange={(e) => setAnalysisId(e.target.value)}
            className="input"
          />
          <button onClick={fetchReport} disabled={loading} className="btn btn-primary">
            {loading ? 'Loading...' : 'Load Report'}
          </button>
        </div>
        {error && <div className="error">{error}</div>}
      </div>

      {report && (
        <>
          <div className="card">
            <h2>Fall Risk Indicator</h2>
            <div 
              className="risk-indicator"
              style={{ 
                backgroundColor: getRiskColor(report.fall_risk.level),
                color: 'white',
                padding: '2rem',
                borderRadius: '8px',
                textAlign: 'center'
              }}
            >
              <h3 style={{ fontSize: '2rem', marginBottom: '1rem' }}>
                {report.fall_risk.level.toUpperCase()}
              </h3>
              <p>{report.fall_risk.description}</p>
            </div>
          </div>

          <div className="card">
            <h2>Key Metrics</h2>
            <div className="metrics-grid">
              <div className="metric">
                <label>Walking Speed</label>
                <div className="value">
                  {report.key_metrics?.walking_speed?.value?.toFixed(2)} m/s
                </div>
              </div>
              <div className="metric">
                <label>Mobility Score</label>
                <div className="value">
                  {report.key_metrics?.mobility_score}/100
                </div>
              </div>
            </div>
          </div>

          {report.trends && Object.keys(report.trends).length > 0 && (
            <div className="card">
              <h2>Trends</h2>
              {Object.entries(report.trends).map(([key, trend]: [string, any]) => (
                <div key={key} className="trend-item">
                  <p><strong>{trend.message}</strong></p>
                </div>
              ))}
            </div>
          )}

          <div className="card">
            <h2>Recommendations</h2>
            <ul>
              {report.recommendations?.map((rec: string, idx: number) => (
                <li key={idx}>{rec}</li>
              ))}
            </ul>
          </div>
        </>
      )}
    </div>
  )
}

