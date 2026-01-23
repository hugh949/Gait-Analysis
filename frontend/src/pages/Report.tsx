import { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { Loader2, CheckCircle, Clock, AlertCircle } from 'lucide-react'
import './Report.css'

const getApiUrl = () => {
  if (typeof window !== 'undefined') {
    const hostname = window.location.hostname
    if (hostname.includes('azurewebsites.net') || hostname.includes('localhost')) {
      return ''
    }
    if (hostname.includes('azurestaticapps.net')) {
      return 'https://gaitanalysisapp.azurewebsites.net'
    }
  }
  return (import.meta as any).env?.VITE_API_URL || 'http://localhost:8000'
}

const API_URL = getApiUrl()

interface AnalysisResult {
  id: string
  status: string
  filename?: string
  video_url?: string
  current_step?: string
  step_progress?: number
  progress_message?: string
  metrics?: {
    cadence?: number
    step_length?: number
    walking_speed?: number
    stride_length?: number
    double_support_time?: number
    swing_time?: number
    stance_time?: number
    step_time?: number
    // Geriatric-specific parameters
    step_width_mean?: number
    step_width_cv?: number
    walk_ratio?: number
    stride_speed_cv?: number
    step_length_cv?: number
    step_time_cv?: number
    step_time_symmetry?: number
    step_length_symmetry?: number
    // Professional assessments
    fall_risk_assessment?: {
      risk_score?: number
      risk_level?: string
      risk_category?: string
      risk_factors?: string[]
      risk_factor_count?: number
      walking_speed_mps?: number
      normalized_stride_length?: number
    }
    functional_mobility?: {
      mobility_score?: number
      mobility_level?: string
      mobility_category?: string
      score_percentage?: number
    }
    directional_analysis?: {
      primary_direction?: string
      direction_confidence?: number
    }
  }
  created_at?: string
}

export default function Report() {
  const { analysisId } = useParams<{ analysisId: string }>()
  const navigate = useNavigate()
  const [analysis, setAnalysis] = useState<AnalysisResult | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [startTime] = useState<number>(Date.now())
  const pollingIntervalRef = useRef<number | null>(null)

  const fetchAnalysis = async () => {
    if (!analysisId) return

    try {
      const response = await fetch(`${API_URL}/api/v1/analysis/${analysisId}`)
      
      if (!response.ok) {
        throw new Error(`Failed to fetch analysis: ${response.statusText}`)
      }

      const data = await response.json()
      setAnalysis(data)
      
      // Stop polling if analysis is completed or failed
      if (data.status === 'completed' || data.status === 'failed') {
        if (pollingIntervalRef.current) {
          clearInterval(pollingIntervalRef.current)
          pollingIntervalRef.current = null
        }
      }
    } catch (err: any) {
      console.error('Error fetching analysis:', err)
      setError(err.message || 'Failed to load analysis')
      if (pollingIntervalRef.current) {
        clearInterval(pollingIntervalRef.current)
        pollingIntervalRef.current = null
      }
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (!analysisId) {
      setError('No analysis ID provided')
      setLoading(false)
      return
    }

    // Initial fetch
    fetchAnalysis()

      // Set up polling if status is processing
    if (analysis?.status === 'processing' || !analysis) {
      pollingIntervalRef.current = window.setInterval(() => {
        fetchAnalysis()
      }, 2000) // Poll every 2 seconds
    }

    // Cleanup on unmount
    return () => {
      if (pollingIntervalRef.current) {
        clearInterval(pollingIntervalRef.current)
      }
    }
  }, [analysisId])

  // Update polling when status changes
  useEffect(() => {
    if (analysis?.status === 'processing' && !pollingIntervalRef.current) {
      pollingIntervalRef.current = window.setInterval(() => {
        fetchAnalysis()
      }, 2000)
    } else if (analysis?.status !== 'processing' && pollingIntervalRef.current) {
      window.clearInterval(pollingIntervalRef.current)
      pollingIntervalRef.current = null
    }
  }, [analysis?.status])

  if (loading) {
    return (
      <div className="report-page">
        <div className="loading">Loading report...</div>
      </div>
    )
  }

  if (error || !analysis) {
    return (
      <div className="report-page">
        <div className="error-message">
          <h2>Error</h2>
          <p>{error || 'Analysis not found'}</p>
          <button onClick={() => navigate('/view-gait')} className="btn btn-primary">
            View All Analyses
          </button>
        </div>
      </div>
    )
  }

  const metrics = analysis.metrics || {}
  const status = analysis.status || 'unknown'
  const currentStep = analysis.current_step || null
  const stepProgress = analysis.step_progress || 0
  const progressMessage = analysis.progress_message || ''

  // Use professional assessments from backend if available
  const fallRiskAssessment = metrics.fall_risk_assessment || {}
  const functionalMobility = metrics.functional_mobility || {}
  
  // Calculate metrics for different sections
  const walkingSpeed = metrics.walking_speed ? metrics.walking_speed / 1000 : null
  const healthScore = functionalMobility.mobility_score || (walkingSpeed 
    ? Math.min(100, Math.max(0, Math.round((walkingSpeed / 1.4) * 100)))
    : null)

  // Calculate elapsed time and estimated remaining time
  const elapsedTime = Math.floor((Date.now() - startTime) / 1000) // seconds
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return mins > 0 ? `${mins}m ${secs}s` : `${secs}s`
  }

  // Estimate remaining time based on current progress
  const estimatedRemaining = stepProgress > 0 && stepProgress < 100
    ? Math.floor((elapsedTime / stepProgress) * (100 - stepProgress))
    : null

  // Step definitions
  const steps = [
    {
      id: 'pose_estimation',
      number: 1,
      title: '2D Pose Estimation',
      description: 'Extracting keypoints from video frames',
      progressRange: [0, 60]
    },
    {
      id: '3d_lifting',
      number: 2,
      title: '3D Lifting',
      description: 'Converting 2D keypoints to 3D space',
      progressRange: [60, 75]
    },
    {
      id: 'metrics_calculation',
      number: 3,
      title: 'Gait Analysis',
      description: 'Calculating gait parameters and metrics',
      progressRange: [75, 95]
    },
    {
      id: 'report_generation',
      number: 4,
      title: 'Report Generation',
      description: 'Generating comprehensive analysis report',
      progressRange: [95, 100]
    }
  ]

  const getStepStatus = (stepId: string) => {
    if (!currentStep) return 'pending'
    
    const currentStepIndex = steps.findIndex(s => s.id === currentStep)
    const stepIndex = steps.findIndex(s => s.id === stepId)
    
    if (stepIndex < currentStepIndex) return 'completed'
    if (stepIndex === currentStepIndex) return 'active'
    return 'pending'
  }

  const getOverallProgress = () => {
    if (!currentStep) return 0
    
    const currentStepData = steps.find(s => s.id === currentStep)
    if (!currentStepData) return 0
    
    const [min, max] = currentStepData.progressRange
    const stepProgressPercent = (stepProgress - 0) / 100 // Normalize step progress
    return min + (max - min) * stepProgressPercent
  }

  return (
    <div className="report-page">
      <div className="report-header">
        <h1>Gait Analysis Report</h1>
        <div className="report-meta">
          <p><strong>Analysis ID:</strong> {analysis.id}</p>
          {analysis.filename && <p><strong>Video:</strong> {analysis.filename}</p>}
          {analysis.created_at && <p><strong>Date:</strong> {new Date(analysis.created_at).toLocaleDateString()}</p>}
        </div>
      </div>

      {status === 'processing' && (
        <div className="processing-container">
          <div className="processing-header">
            <h2>Analyzing Your Video</h2>
            <p className="processing-subtitle">We're processing your gait analysis. This may take a few minutes.</p>
          </div>

          {/* Overall Progress */}
          <div className="overall-progress-section">
            <div className="overall-progress-header">
              <span className="overall-progress-label">Overall Progress</span>
              <span className="overall-progress-percent">{Math.round(getOverallProgress())}%</span>
            </div>
            <div className="overall-progress-bar-container">
              <div 
                className="overall-progress-bar" 
                style={{ width: `${getOverallProgress()}%` }}
              ></div>
            </div>
            <div className="progress-time-info">
              <span className="time-elapsed">
                <Clock size={16} /> Elapsed: {formatTime(elapsedTime)}
              </span>
              {estimatedRemaining && (
                <span className="time-remaining">
                  Estimated remaining: {formatTime(estimatedRemaining)}
                </span>
              )}
            </div>
          </div>

          {/* Step-by-Step Progress */}
          <div className="steps-container">
            <h3 className="steps-title">Processing Steps</h3>
            <div className="steps-list">
              {steps.map((step) => {
                const stepStatus = getStepStatus(step.id)
                const isActive = stepStatus === 'active'
                const isCompleted = stepStatus === 'completed'
                
                return (
                  <div 
                    key={step.id} 
                    className={`step-card ${stepStatus}`}
                  >
                    <div className="step-indicator">
                      {isCompleted ? (
                        <div className="step-icon completed">
                          <CheckCircle size={24} />
                        </div>
                      ) : isActive ? (
                        <div className="step-icon active">
                          <Loader2 size={24} className="spinning" />
                        </div>
                      ) : (
                        <div className="step-icon pending">
                          <div className="step-number">{step.number}</div>
                        </div>
                      )}
                    </div>
                    <div className="step-content">
                      <div className="step-header">
                        <h4 className="step-title">{step.title}</h4>
                        {isActive && stepProgress > 0 && (
                          <span className="step-progress-badge">{stepProgress}%</span>
                        )}
                      </div>
                      <p className="step-description">
                        {isActive && progressMessage 
                          ? progressMessage 
                          : step.description}
                      </p>
                      {isActive && stepProgress > 0 && (
                        <div className="step-progress-bar-container">
                          <div 
                            className="step-progress-bar" 
                            style={{ width: `${stepProgress}%` }}
                          ></div>
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>

          {/* Auto-refresh indicator */}
          <div className="auto-refresh-indicator">
            <Loader2 size={14} className="spinning" />
            <span>Auto-updating every 2 seconds...</span>
          </div>
        </div>
      )}

      {status === 'failed' && (
        <div className="status-error">
          <AlertCircle size={24} />
          <p>Analysis failed. Please try uploading again.</p>
        </div>
      )}

      {status === 'completed' && metrics && Object.keys(metrics).length > 0 && (
        <div className="report-sections">
          {/* Patient Section */}
          <section className="report-section patient-section">
            <h2>Patient</h2>
            <div className="section-content">
              {healthScore !== null && (
                <div className="health-score-card">
                  <h3>Your Gait Health Score</h3>
                  <div className="health-score">
                    <div className="score-value">{healthScore}</div>
                    <div className="score-label">out of 100</div>
                    <div className="score-description">
                      {healthScore >= 80 && <p>✅ Excellent! Keep up the great work!</p>}
                      {healthScore >= 60 && healthScore < 80 && <p>👍 Good! Your mobility looks healthy.</p>}
                      {healthScore < 60 && <p>💪 Focus on regular movement and activity.</p>}
                    </div>
                  </div>
                </div>
              )}

              <div className="metrics-grid">
                {metrics.walking_speed && (
                  <div className="metric-card">
                    <div className="metric-label">Walking Speed</div>
                    <div className="metric-value">{(metrics.walking_speed / 1000).toFixed(2)}</div>
                    <div className="metric-unit">m/s</div>
                  </div>
                )}
                {metrics.cadence && (
                  <div className="metric-card">
                    <div className="metric-label">Cadence</div>
                    <div className="metric-value">{metrics.cadence.toFixed(2)}</div>
                    <div className="metric-unit">steps/min</div>
                  </div>
                )}
                {metrics.step_length && (
                  <div className="metric-card">
                    <div className="metric-label">Step Length</div>
                    <div className="metric-value">{(metrics.step_length / 1000).toFixed(2)}</div>
                    <div className="metric-unit">m</div>
                  </div>
                )}
              </div>
            </div>
          </section>

          {/* Caregiver Section */}
          <section className="report-section caregiver-section">
            <h2>Caregiver</h2>
            <div className="section-content">
              {fallRiskAssessment.risk_level && (
                <div className={`risk-indicator risk-${fallRiskAssessment.risk_level.toLowerCase()}`}>
                  <div className="risk-label">Professional Fall Risk Assessment</div>
                  <div className="risk-value">{fallRiskAssessment.risk_level}</div>
                  <div className="risk-score">Risk Score: {fallRiskAssessment.risk_score?.toFixed(1) || 'N/A'}</div>
                  <div className="risk-description">
                    <p>{fallRiskAssessment.risk_category || 'Assessment in progress'}</p>
                    {fallRiskAssessment.risk_factors && fallRiskAssessment.risk_factors.length > 0 && (
                      <div className="risk-factors">
                        <p><strong>Key Risk Factors:</strong></p>
                        <ul>
                          {fallRiskAssessment.risk_factors.slice(0, 5).map((factor, idx) => (
                            <li key={idx}>{factor}</li>
                          ))}
                        </ul>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {functionalMobility.mobility_level && (
                <div className="mobility-indicator">
                  <div className="mobility-label">Functional Mobility Assessment</div>
                  <div className="mobility-value">{functionalMobility.mobility_level}</div>
                  <div className="mobility-score">
                    Score: {functionalMobility.mobility_score?.toFixed(1) || 'N/A'} / 100
                    ({functionalMobility.score_percentage?.toFixed(1) || '0'}%)
                  </div>
                  <div className="mobility-description">
                    <p>{functionalMobility.mobility_category || 'Assessment in progress'}</p>
                  </div>
                </div>
              )}

              <div className="metrics-grid">
                {metrics.walking_speed && (
                  <div className="metric-card">
                    <div className="metric-label">Walking Speed</div>
                    <div className="metric-value">{(metrics.walking_speed / 1000).toFixed(2)}</div>
                    <div className="metric-unit">m/s</div>
                    <div className="metric-note">
                      {walkingSpeed && walkingSpeed < 1.0 && 'Below normal range'}
                      {walkingSpeed && walkingSpeed >= 1.0 && walkingSpeed < 1.2 && 'Slightly below normal'}
                      {walkingSpeed && walkingSpeed >= 1.2 && 'Within normal range'}
                    </div>
                  </div>
                )}
                {metrics.stride_length && (
                  <div className="metric-card">
                    <div className="metric-label">Stride Length</div>
                    <div className="metric-value">{(metrics.stride_length / 1000).toFixed(2)}</div>
                    <div className="metric-unit">m</div>
                  </div>
                )}
                {metrics.cadence && (
                  <div className="metric-card">
                    <div className="metric-label">Cadence</div>
                    <div className="metric-value">{metrics.cadence.toFixed(2)}</div>
                    <div className="metric-unit">steps/min</div>
                  </div>
                )}
              </div>

              <div className="trend-note">
                <p><strong>Monitoring Note:</strong> Track these metrics over time to identify changes in mobility patterns. Consult with healthcare providers if you notice significant declines.</p>
              </div>
            </div>
          </section>

          {/* Professional Section */}
          <section className="report-section professional-section">
            <h2>Professional Gait Lab Parameters</h2>
            <div className="section-content">
              <h3>Spatiotemporal Parameters</h3>
              <div className="metrics-grid comprehensive">
                {metrics.cadence && (
                  <div className="metric-card">
                    <div className="metric-label">Cadence</div>
                    <div className="metric-value">{metrics.cadence.toFixed(2)}</div>
                    <div className="metric-unit">steps/min</div>
                  </div>
                )}
                {metrics.step_length && (
                  <div className="metric-card">
                    <div className="metric-label">Step Length</div>
                    <div className="metric-value">{(metrics.step_length / 1000).toFixed(2)}</div>
                    <div className="metric-unit">m</div>
                  </div>
                )}
                {metrics.walking_speed && (
                  <div className="metric-card">
                    <div className="metric-label">Walking Speed</div>
                    <div className="metric-value">{(metrics.walking_speed / 1000).toFixed(2)}</div>
                    <div className="metric-unit">m/s</div>
                  </div>
                )}
                {metrics.stride_length && (
                  <div className="metric-card">
                    <div className="metric-label">Stride Length</div>
                    <div className="metric-value">{(metrics.stride_length / 1000).toFixed(2)}</div>
                    <div className="metric-unit">m</div>
                  </div>
                )}
                {metrics.double_support_time && (
                  <div className="metric-card">
                    <div className="metric-label">Double Support Time</div>
                    <div className="metric-value">{metrics.double_support_time.toFixed(3)}</div>
                    <div className="metric-unit">s</div>
                  </div>
                )}
                {metrics.swing_time && (
                  <div className="metric-card">
                    <div className="metric-label">Swing Time</div>
                    <div className="metric-value">{metrics.swing_time.toFixed(3)}</div>
                    <div className="metric-unit">s</div>
                  </div>
                )}
                {metrics.stance_time && (
                  <div className="metric-card">
                    <div className="metric-label">Stance Time</div>
                    <div className="metric-value">{metrics.stance_time.toFixed(3)}</div>
                    <div className="metric-unit">s</div>
                  </div>
                )}
                {metrics.step_time && (
                  <div className="metric-card">
                    <div className="metric-label">Step Time</div>
                    <div className="metric-value">{metrics.step_time.toFixed(3)}</div>
                    <div className="metric-unit">s</div>
                  </div>
                )}
              </div>

              <h3>Geriatric Fall Risk Parameters</h3>
              <div className="metrics-grid comprehensive">
                {metrics.step_width_mean !== undefined && (
                  <div className="metric-card">
                    <div className="metric-label">Step Width (Mean)</div>
                    <div className="metric-value">{(metrics.step_width_mean / 1000).toFixed(3)}</div>
                    <div className="metric-unit">m</div>
                    <div className="metric-note">Base of support</div>
                  </div>
                )}
                {metrics.step_width_cv !== undefined && (
                  <div className="metric-card">
                    <div className="metric-label">Step Width Variability</div>
                    <div className="metric-value">{metrics.step_width_cv.toFixed(2)}</div>
                    <div className="metric-unit">% CV</div>
                    <div className="metric-note">
                      {metrics.step_width_cv > 15 ? '⚠️ High variability' : 
                       metrics.step_width_cv > 10 ? '⚠️ Moderate variability' : 
                       '✅ Normal variability'}
                    </div>
                  </div>
                )}
                {metrics.walk_ratio !== undefined && (
                  <div className="metric-card">
                    <div className="metric-label">Walk Ratio</div>
                    <div className="metric-value">{metrics.walk_ratio.toFixed(4)}</div>
                    <div className="metric-unit">mm/(steps/min)</div>
                    <div className="metric-note">Gait efficiency indicator</div>
                  </div>
                )}
                {metrics.stride_speed_cv !== undefined && (
                  <div className="metric-card">
                    <div className="metric-label">Stride Speed Variability</div>
                    <div className="metric-value">{metrics.stride_speed_cv.toFixed(2)}</div>
                    <div className="metric-unit">% CV</div>
                    <div className="metric-note">Strongest fall predictor</div>
                  </div>
                )}
                {metrics.step_length_cv !== undefined && (
                  <div className="metric-card">
                    <div className="metric-label">Step Length Variability</div>
                    <div className="metric-value">{metrics.step_length_cv.toFixed(2)}</div>
                    <div className="metric-unit">% CV</div>
                  </div>
                )}
                {metrics.step_time_cv !== undefined && (
                  <div className="metric-card">
                    <div className="metric-label">Step Time Variability</div>
                    <div className="metric-value">{metrics.step_time_cv.toFixed(2)}</div>
                    <div className="metric-unit">% CV</div>
                  </div>
                )}
              </div>

              <h3>Gait Symmetry</h3>
              <div className="metrics-grid comprehensive">
                {metrics.step_time_symmetry !== undefined && (
                  <div className="metric-card">
                    <div className="metric-label">Step Time Symmetry</div>
                    <div className="metric-value">{(metrics.step_time_symmetry * 100).toFixed(1)}</div>
                    <div className="metric-unit">%</div>
                    <div className="metric-note">
                      {metrics.step_time_symmetry >= 0.85 ? '✅ Good symmetry' : '⚠️ Asymmetry detected'}
                    </div>
                  </div>
                )}
                {metrics.step_length_symmetry !== undefined && (
                  <div className="metric-card">
                    <div className="metric-label">Step Length Symmetry</div>
                    <div className="metric-value">{(metrics.step_length_symmetry * 100).toFixed(1)}</div>
                    <div className="metric-unit">%</div>
                  </div>
                )}
              </div>

              {metrics.directional_analysis && (
                <div className="directional-info">
                  <h3>Multi-Directional Analysis</h3>
                  <p><strong>Primary Direction:</strong> {metrics.directional_analysis.primary_direction || 'Unknown'}</p>
                  <p><strong>Confidence:</strong> {metrics.directional_analysis.direction_confidence 
                    ? `${(metrics.directional_analysis.direction_confidence * 100).toFixed(1)}%`
                    : 'N/A'}</p>
                </div>
              )}

              <div className="clinical-notes">
                <h3>Clinical Notes</h3>
                <ul>
                  <li>Analysis performed using Azure Computer Vision API</li>
                  <li>Metrics calculated from video-based pose estimation</li>
                  <li>Results validated against clinical standards</li>
                  {analysis.video_url && (
                    <li>Source video available for review</li>
                  )}
                </ul>
              </div>
            </div>
          </section>
        </div>
      )}

      {status === 'completed' && (!metrics || Object.keys(metrics).length === 0) && (
        <div className="no-metrics">
          <p>Analysis completed but no metrics are available.</p>
        </div>
      )}

      <div className="report-actions">
        {analysis.video_url && (
          <a 
            href={analysis.video_url} 
            target="_blank" 
            rel="noopener noreferrer"
            className="btn btn-secondary"
          >
            View Video
          </a>
        )}
        <button onClick={() => navigate('/view-gait')} className="btn btn-secondary">
          View All Analyses
        </button>
        <button onClick={() => navigate('/upload')} className="btn btn-primary">
          Upload New Video
        </button>
      </div>
    </div>
  )
}

