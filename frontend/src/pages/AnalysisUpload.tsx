import { useState, useEffect, useRef } from 'react'
import axios from 'axios'
import './AnalysisUpload.css'

const API_URL = (import.meta as any).env?.VITE_API_URL || 'http://localhost:8000'

type AnalysisStatus = 'idle' | 'uploading' | 'processing' | 'completed' | 'failed'

export default function AnalysisUpload() {
  const [file, setFile] = useState<File | null>(null)
  const [uploadProgress, setUploadProgress] = useState(0)
  const [status, setStatus] = useState<AnalysisStatus>('idle')
  const [analysisId, setAnalysisId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [statusMessage, setStatusMessage] = useState<string>('')
  const pollingIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setFile(e.target.files[0])
      setError(null)
      setStatus('idle')
      setUploadProgress(0)
    }
  }

  const checkAnalysisStatus = async (id: string) => {
    try {
      const response = await axios.get(`${API_URL}/api/v1/analysis/${id}`)
      const analysisStatus = response.data.status

      if (analysisStatus === 'completed') {
        setStatus('completed')
        setStatusMessage('Analysis completed successfully!')
        if (pollingIntervalRef.current) {
          clearInterval(pollingIntervalRef.current)
        }
      } else if (analysisStatus === 'failed') {
        setStatus('failed')
        setError(response.data.error || 'Analysis failed')
        if (pollingIntervalRef.current) {
          clearInterval(pollingIntervalRef.current)
        }
      } else if (analysisStatus === 'processing') {
        setStatus('processing')
        // Update message based on processing stage (if available)
        setStatusMessage('Processing video and analyzing gait patterns...')
      }
    } catch (err: any) {
      console.error('Error checking analysis status:', err)
      // Don't set error here - might be temporary
    }
  }

  useEffect(() => {
    // Cleanup polling on unmount
    return () => {
      if (pollingIntervalRef.current) {
        clearInterval(pollingIntervalRef.current)
      }
    }
  }, [])

  useEffect(() => {
    // Start polling when analysis ID is set and status is processing
    if (analysisId && status === 'processing') {
      // Check immediately
      checkAnalysisStatus(analysisId)
      
      // Then poll every 3 seconds
      pollingIntervalRef.current = setInterval(() => {
        checkAnalysisStatus(analysisId)
      }, 3000)
    }

    return () => {
      if (pollingIntervalRef.current) {
        clearInterval(pollingIntervalRef.current)
      }
    }
  }, [analysisId, status])

  const handleUpload = async () => {
    if (!file) {
      setError('Please select a file')
      return
    }

    setStatus('uploading')
    setUploadProgress(0)
    setError(null)
    setStatusMessage('Preparing to upload video...')

    const formData = new FormData()
    formData.append('file', file)

    try {
      const response = await axios.post(`${API_URL}/api/v1/analysis/upload`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        timeout: 300000, // 5 minutes timeout for large files
        onUploadProgress: (progressEvent) => {
          if (progressEvent.total) {
            const percentCompleted = Math.round(
              (progressEvent.loaded * 100) / progressEvent.total
            )
            setUploadProgress(percentCompleted)
            setStatusMessage(`Uploading video... ${percentCompleted}%`)
          }
        },
      })

      setAnalysisId(response.data.analysis_id)
      setStatus('processing')
      setStatusMessage('Video uploaded! Starting analysis...')
      setUploadProgress(100)
    } catch (err: any) {
      setStatus('failed')
      
      // Provide more detailed error messages
      let errorMessage = 'Upload failed'
      
      if (err.response) {
        // Server responded with error
        errorMessage = err.response.data?.detail || err.response.data?.message || `Server error: ${err.response.status}`
      } else if (err.request) {
        // Request made but no response
        if (err.code === 'ECONNABORTED') {
          errorMessage = 'Upload timeout - The file may be too large or the server is taking too long to respond. Please try again.'
        } else if (err.code === 'ERR_NETWORK') {
          errorMessage = 'Network error - Cannot connect to server. The server may be starting up (this can take 30-60 seconds). Please wait and try again.'
        } else {
          errorMessage = `Network error: ${err.message || 'Unable to connect to server'}`
        }
      } else {
        // Error setting up request
        errorMessage = `Error: ${err.message || 'Unknown error'}`
      }
      
      setError(errorMessage)
      setStatusMessage('')
      setUploadProgress(0)
    }
  }

  const getStatusIcon = () => {
    switch (status) {
      case 'uploading':
      case 'processing':
        return '⏳'
      case 'completed':
        return '✅'
      case 'failed':
        return '❌'
      default:
        return ''
    }
  }

  return (
    <div className="upload-page">
      <div className="card">
        <h2>Upload Video for Analysis</h2>
        <p className="description">
          Upload a video file for gait analysis. Supported formats: MP4, AVI, MOV, MKV
        </p>

        <div className="upload-section">
          <input
            type="file"
            accept="video/*"
            onChange={handleFileChange}
            disabled={status === 'uploading' || status === 'processing'}
            className="file-input"
          />

          {file && (
            <div className="file-info">
              <p><strong>Selected:</strong> {file.name}</p>
              <p><strong>Size:</strong> {(file.size / (1024 * 1024)).toFixed(2)} MB</p>
            </div>
          )}

          {/* Upload Progress Bar */}
          {(status === 'uploading' || status === 'processing') && (
            <div className="progress-container">
              <div className="progress-bar-wrapper">
                <div 
                  className="progress-bar" 
                  style={{ width: `${uploadProgress}%` }}
                ></div>
              </div>
              <p className="progress-text">{uploadProgress}%</p>
            </div>
          )}

          {/* Status Message */}
          {statusMessage && (
            <div className={`status-message status-${status}`}>
              <span className="status-icon">{getStatusIcon()}</span>
              <span>{statusMessage}</span>
            </div>
          )}

          <button
            onClick={handleUpload}
            disabled={!file || status === 'uploading' || status === 'processing'}
            className="btn btn-primary"
          >
            {status === 'uploading' ? 'Uploading...' : 
             status === 'processing' ? 'Processing...' : 
             'Upload and Analyze'}
          </button>

          {error && <div className="error">{error}</div>}

          {/* Analysis Complete Message */}
          {status === 'completed' && analysisId && (
            <div className="completion-message">
              <h3>✅ Analysis Complete!</h3>
              <p>Your gait analysis has been completed successfully.</p>
              <div className="dashboard-links">
                <p><strong>View your results in:</strong></p>
                <ul>
                  <li>
                    <strong>Medical Dashboard</strong> - Technical details, biomechanical parameters, and clinical interpretation
                  </li>
                  <li>
                    <strong>Caregiver Dashboard</strong> - Fall risk indicator, trends, and monitoring insights
                  </li>
                  <li>
                    <strong>Your Dashboard</strong> - Simple health score and easy-to-understand summary
                  </li>
                </ul>
                <p className="analysis-id">
                  <strong>Analysis ID:</strong> <code>{analysisId}</code>
                </p>
                <p className="note">
                  Use this ID to view results in any of the dashboards above.
                </p>
              </div>
            </div>
          )}

          {/* Processing Status Details */}
          {status === 'processing' && analysisId && (
            <div className="processing-details">
              <div className="processing-steps">
                <div className="step active">
                  <span className="step-number">1</span>
                  <span className="step-text">Extracting pose keypoints from video</span>
                </div>
                <div className="step active">
                  <span className="step-number">2</span>
                  <span className="step-text">Converting to 3D biomechanical model</span>
                </div>
                <div className="step active">
                  <span className="step-number">3</span>
                  <span className="step-text">Calculating gait metrics</span>
                </div>
                <div className="step">
                  <span className="step-number">4</span>
                  <span className="step-text">Generating reports</span>
                </div>
              </div>
              <p className="processing-note">
                This may take a few minutes. Please keep this page open.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

