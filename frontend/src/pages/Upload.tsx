/**
 * Upload Page - Clean, simple interface for video upload
 */
import { useState, useEffect, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { getSASToken, uploadToBlobStorage, processVideo, getAnalysis } from '../services/api'
import './Upload.css'

type UploadStatus = 'idle' | 'getting-token' | 'uploading' | 'processing' | 'completed' | 'failed'

export default function Upload() {
  const navigate = useNavigate()
  const [file, setFile] = useState<File | null>(null)
  const [uploadProgress, setUploadProgress] = useState(0)
  const [status, setStatus] = useState<UploadStatus>('idle')
  const [analysisId, setAnalysisId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [statusMessage, setStatusMessage] = useState<string>('')
  const pollingIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  useEffect(() => {
    return () => {
      if (pollingIntervalRef.current) {
        clearInterval(pollingIntervalRef.current)
      }
    }
  }, [])

  useEffect(() => {
    if (analysisId && status === 'processing') {
      const checkStatus = async () => {
        try {
          const result = await getAnalysis(analysisId)
          if (result.status === 'completed') {
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

    try {
      // Generate blob name
      const blobName = generateBlobName(file.name)

      // Get SAS token
      setStatusMessage('Getting upload permissions...')
      const sasResponse = await getSASToken(blobName, 60)

      // Upload to blob storage
      setStatus('uploading')
      setStatusMessage('Uploading video...')
      setUploadProgress(0)

      await uploadToBlobStorage(file, sasResponse.sas_url, (progress) => {
        setUploadProgress(progress)
        setStatusMessage(`Uploading video... ${Math.round(progress)}%`)
      })

      // Trigger processing
      setStatus('processing')
      setStatusMessage('Starting analysis...')
      setUploadProgress(100)

      const processResponse = await processVideo({
        blob_name: blobName,
        view_type: 'front',
        fps: 30.0,
      })

      setAnalysisId(processResponse.analysis_id)
      setStatusMessage('Analysis in progress...')

    } catch (err: any) {
      setStatus('failed')
      setError(err.message || 'Upload failed. Please try again.')
      setStatusMessage('')
      setUploadProgress(0)
    }
  }

  return (
    <div className="upload-page">
      <div className="upload-container">
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
              disabled={status === 'uploading' || status === 'processing' || status === 'getting-token'}
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
            <div className="success-section">
              <h3>✅ Analysis Complete!</h3>
              <p>Your gait analysis has been completed successfully.</p>
              <div className="actions">
                <button
                  onClick={() => navigate(`/analysis/${analysisId}`)}
                  className="view-results-button"
                >
                  View Results
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

