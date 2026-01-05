/**
 * Improved Upload Page with Sequential Step Progress and Report Viewing
 */
import { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { getSASToken, uploadToBlobStorage, processVideo, getAnalysis } from '../services/api'
import './UploadImproved.css'

type UploadStatus = 'idle' | 'getting-token' | 'uploading' | 'processing' | 'completed' | 'failed'

type ProcessingStep = 
  | 'pose_estimation'
  | '3d_lifting'
  | 'metrics_calculation'
  | 'report_generation'
  | 'completed'

const PROCESSING_STEPS: Array<{ key: ProcessingStep; label: string; description: string }> = [
  { key: 'pose_estimation', label: 'Step 1', description: 'Extracting pose keypoints from video' },
  { key: '3d_lifting', label: 'Step 2', description: 'Converting to 3D biomechanical model' },
  { key: 'metrics_calculation', label: 'Step 3', description: 'Calculating gait metrics' },
  { key: 'report_generation', label: 'Step 4', description: 'Generating reports' },
]

export default function UploadImproved() {
  const navigate = useNavigate()
  const [file, setFile] = useState<File | null>(null)
  const [uploadProgress, setUploadProgress] = useState(0)
  const [status, setStatus] = useState<UploadStatus>('idle')
  const [currentStep, setCurrentStep] = useState<ProcessingStep | null>(null)
  const [completedSteps, setCompletedSteps] = useState<Set<ProcessingStep>>(new Set())
  const [analysisId, setAnalysisId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [statusMessage, setStatusMessage] = useState<string>('')
  const pollingIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const stepTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    return () => {
      if (pollingIntervalRef.current) {
        clearInterval(pollingIntervalRef.current)
      }
      if (stepTimeoutRef.current) {
        clearTimeout(stepTimeoutRef.current)
      }
    }
  }, [])

  // Simulate sequential step progress (since backend doesn't expose step info yet)
  useEffect(() => {
    if (status === 'processing' && !currentStep) {
      // Start with first step
      setCurrentStep('pose_estimation')
      
      // Simulate sequential progression (actual implementation would use backend status)
      const stepDurations: Record<Exclude<ProcessingStep, 'completed'>, number> = {
        pose_estimation: 15000, // 15 seconds
        '3d_lifting': 12000, // 12 seconds
        metrics_calculation: 10000, // 10 seconds
        report_generation: 8000, // 8 seconds
      }

      let stepIndex = 0
      const progressSteps = () => {
        if (stepIndex < PROCESSING_STEPS.length) {
          const step = PROCESSING_STEPS[stepIndex]
          setCurrentStep(step.key)
          
          // Mark previous steps as completed
          if (stepIndex > 0) {
            setCompletedSteps(prev => new Set([...prev, PROCESSING_STEPS[stepIndex - 1].key]))
          }

          stepIndex++
          if (stepIndex < PROCESSING_STEPS.length) {
            const duration = step.key !== 'completed' ? (stepDurations[step.key] || 10000) : 10000
            stepTimeoutRef.current = setTimeout(progressSteps, duration)
          } else {
            // All steps complete
            setCompletedSteps(prev => new Set([...prev, step.key]))
            setCurrentStep('completed')
          }
        }
      }

      stepTimeoutRef.current = setTimeout(progressSteps, stepDurations.pose_estimation)
    }

    return () => {
      if (stepTimeoutRef.current) {
        clearTimeout(stepTimeoutRef.current)
      }
    }
  }, [status, currentStep])

  useEffect(() => {
    if (analysisId && status === 'processing') {
      const checkStatus = async () => {
        try {
          const result = await getAnalysis(analysisId)
          if (result.status === 'completed') {
            // Mark all steps as completed
            setCompletedSteps(new Set(PROCESSING_STEPS.map(s => s.key)))
            setCurrentStep('completed')
            setStatus('completed')
            setStatusMessage('Analysis completed successfully!')
            if (pollingIntervalRef.current) {
              clearInterval(pollingIntervalRef.current)
            }
          } else if (result.status === 'failed') {
            setStatus('failed')
            setError(result.error || 'Analysis failed')
            if (pollingIntervalRef.current) {
              clearInterval(pollingIntervalRef.current)
            }
          }
        } catch (err) {
          console.error('Error checking status:', err)
        }
      }

      checkStatus()
      pollingIntervalRef.current = setInterval(checkStatus, 3000)
    }

    return () => {
      if (pollingIntervalRef.current) {
        clearInterval(pollingIntervalRef.current)
      }
    }
  }, [analysisId, status])

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setFile(e.target.files[0])
      setError(null)
      setStatus('idle')
      setUploadProgress(0)
      setCurrentStep(null)
      setCompletedSteps(new Set())
    }
  }

  const generateBlobName = (fileName: string): string => {
    const timestamp = Date.now()
    const sanitized = fileName.replace(/[^a-zA-Z0-9.-]/g, '_')
    return `videos/${timestamp}_${sanitized}`
  }

  const handleUpload = async () => {
    if (!file) {
      setError('Please select a file')
      return
    }

    setError(null)
    setStatus('getting-token')
    setStatusMessage('Preparing upload...')
    setCurrentStep(null)
    setCompletedSteps(new Set())

    try {
      const blobName = generateBlobName(file.name)

      setStatusMessage('Getting upload permissions...')
      const sasResponse = await getSASToken(blobName, 60)

      setStatus('uploading')
      setStatusMessage('Uploading video...')
      setUploadProgress(0)

      await uploadToBlobStorage(file, sasResponse.sas_url, (progress) => {
        setUploadProgress(progress)
        setStatusMessage(`Uploading video... ${Math.round(progress)}%`)
      })

      setStatus('processing')
      setStatusMessage('Starting analysis...')
      setUploadProgress(100)

      const processResponse = await processVideo({
        blob_name: blobName,
        view_type: 'front',
        fps: 30.0,
      })

      setAnalysisId(processResponse.analysis_id)
      setStatusMessage('Processing video...')

    } catch (err: any) {
      setStatus('failed')
      setError(err.message || 'Upload failed. Please try again.')
      setStatusMessage('')
      setUploadProgress(0)
      setCurrentStep(null)
    }
  }

  const getStepStatus = (stepKey: ProcessingStep) => {
    if (completedSteps.has(stepKey)) {
      return 'completed'
    }
    if (currentStep === stepKey) {
      return 'active'
    }
    if (currentStep && PROCESSING_STEPS.findIndex(s => s.key === currentStep) > PROCESSING_STEPS.findIndex(s => s.key === stepKey)) {
      return 'completed'
    }
    return 'pending'
  }

  const viewReport = (audience: 'medical' | 'caregiver' | 'older-adult') => {
    if (analysisId) {
      // Navigate directly to appropriate dashboard with analysis ID
      const routes: Record<string, string> = {
        'medical': '/medical',
        'caregiver': '/caregiver',
        'older-adult': '/older-adult'
      }
      navigate(`${routes[audience]}?analysisId=${analysisId}`)
    }
  }

  return (
    <div className="upload-improved-page">
      <div className="upload-improved-container">
        <div className="upload-header">
          <h1>Upload Video for Analysis</h1>
          <p className="upload-description">
            Upload a video file for gait analysis. Supported formats: MP4, AVI, MOV, MKV
          </p>
        </div>

        <div className="upload-card">
          <div className="file-selector">
            <input
              type="file"
              id="video-file"
              accept="video/*"
              onChange={handleFileChange}
              disabled={status !== 'idle'}
              className="file-input"
            />
            <label htmlFor="video-file" className="file-label">
              {file ? file.name : 'Choose video file'}
            </label>
          </div>

          {file && (
            <div className="file-info">
              <div className="info-row">
                <span className="info-label">File:</span>
                <span className="info-value">{file.name}</span>
              </div>
              <div className="info-row">
                <span className="info-label">Size:</span>
                <span className="info-value">{(file.size / (1024 * 1024)).toFixed(2)} MB</span>
              </div>
            </div>
          )}

          {(status === 'uploading' || status === 'processing') && (
            <div className="progress-section">
              <div className="progress-bar">
                <div 
                  className="progress-fill" 
                  style={{ width: `${uploadProgress}%` }}
                />
              </div>
              <p className="progress-text">{Math.round(uploadProgress)}%</p>
            </div>
          )}

          {statusMessage && (
            <div className={`status-message status-${status}`}>
              {statusMessage}
            </div>
          )}

          {status === 'processing' && (
            <div className="processing-steps-container">
              <h3 className="processing-title">Processing Steps</h3>
              <div className="processing-steps">
                {PROCESSING_STEPS.map((step, index) => {
                  const stepStatus = getStepStatus(step.key)
                  return (
                    <div key={step.key} className={`processing-step step-${stepStatus}`}>
                      <div className="step-indicator">
                        {stepStatus === 'completed' && <span className="step-check">✓</span>}
                        {stepStatus === 'active' && <span className="step-spinner">⟳</span>}
                        {stepStatus === 'pending' && <span className="step-number">{index + 1}</span>}
                      </div>
                      <div className="step-content">
                        <div className="step-label">{step.label}</div>
                        <div className="step-description">{step.description}</div>
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
          )}

          <button
            onClick={handleUpload}
            disabled={!file || status !== 'idle'}
            className="upload-button"
          >
            {status === 'getting-token' && 'Preparing...'}
            {status === 'uploading' && 'Uploading...'}
            {status === 'processing' && 'Processing...'}
            {status === 'idle' && 'Upload and Analyze'}
          </button>

          {error && (
            <div className="error-message">
              {error}
            </div>
          )}

          {status === 'completed' && analysisId && (
            <div className="completion-section">
              <div className="completion-header">
                <div className="completion-icon">✓</div>
                <h2>Report Ready!</h2>
                <p className="completion-message">
                  Your gait analysis has been completed successfully. View your detailed report below.
                </p>
              </div>

              <div className="report-buttons">
                <button
                  onClick={() => viewReport('medical')}
                  className="report-button report-button-medical"
                >
                  <div className="report-button-icon">🏥</div>
                  <div className="report-button-content">
                    <div className="report-button-title">Medical Professional</div>
                    <div className="report-button-description">Technical details & clinical interpretation</div>
                  </div>
                </button>

                <button
                  onClick={() => viewReport('caregiver')}
                  className="report-button report-button-caregiver"
                >
                  <div className="report-button-icon">👨‍👩‍👧</div>
                  <div className="report-button-content">
                    <div className="report-button-title">Family Caregiver</div>
                    <div className="report-button-description">Fall risk indicators & monitoring</div>
                  </div>
                </button>

                <button
                  onClick={() => viewReport('older-adult')}
                  className="report-button report-button-patient"
                >
                  <div className="report-button-icon">👤</div>
                  <div className="report-button-content">
                    <div className="report-button-title">Older Adult</div>
                    <div className="report-button-description">Simple health score & summary</div>
                  </div>
                </button>
              </div>

              <div className="analysis-id-section">
                <span className="analysis-id-label">Analysis ID:</span>
                <code className="analysis-id-code">{analysisId}</code>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

