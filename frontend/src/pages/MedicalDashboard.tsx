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

interface MedicalReport {
  biomechanical_parameters: any
  normative_comparison: any
  confidence_metrics: any
  clinical_interpretation: any
}

export default function MedicalDashboard() {
  const [analysisId, setAnalysisId] = useState<string>('')
  const [report, setReport] = useState<MedicalReport | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const fetchReport = async () => {
    if (!analysisId) return

    setLoading(true)
    setError(null)

    try {
      const response = await axios.get(
        `${API_URL}/api/v1/reports/${analysisId}?audience=medical`
      )
      setReport(response.data)
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to fetch report')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="dashboard">
      <h1>Medical Professional Dashboard</h1>
      <p className="subtitle">Technical dossier with biomechanical tabulations and confidence metrics</p>

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
            <h2>Biomechanical Parameters</h2>
            <div className="metrics-grid">
              <div className="metric">
                <label>Gait Speed</label>
                <div className="value">
                  {report.biomechanical_parameters?.spatiotemporal?.gait_speed_m_per_s?.toFixed(2)} m/s
                </div>
              </div>
              <div className="metric">
                <label>Stride Length</label>
                <div className="value">
                  {report.biomechanical_parameters?.spatiotemporal?.stride_length_cm?.toFixed(1)} cm
                </div>
              </div>
              <div className="metric">
                <label>Cadence</label>
                <div className="value">
                  {report.biomechanical_parameters?.spatiotemporal?.cadence_steps_per_min?.toFixed(0)} steps/min
                </div>
              </div>
            </div>
          </div>

          <div className="card">
            <h2>Confidence Metrics</h2>
            <p>Overall Confidence: {(report.confidence_metrics?.overall_confidence * 100).toFixed(1)}%</p>
            <p>Uncertainty Bounds: ±{report.confidence_metrics?.uncertainty_bounds?.joint_angle_uncertainty_deg?.toFixed(1)}°</p>
          </div>

          <div className="card">
            <h2>Clinical Interpretation</h2>
            <p>{report.clinical_interpretation?.summary}</p>
            <ul>
              {report.clinical_interpretation?.interpretations?.map((item: any, idx: number) => (
                <li key={idx}>
                  <strong>{item.metric}</strong>: {item.interpretation}
                </li>
              ))}
            </ul>
          </div>
        </>
      )}
    </div>
  )
}

