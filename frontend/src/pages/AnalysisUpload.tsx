import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import './AnalysisUpload.css'

const getApiUrl = () => {
  if (typeof window !== 'undefined' && window.location.hostname.includes('azurestaticapps.net')) {
    return 'https://gait-analysis-api-simple.azurewebsites.net'
  }
  return (import.meta as any).env?.VITE_API_URL || 'http://localhost:8000'
}

const API_URL = getApiUrl()

export default function AnalysisUpload() {
  const [file, setFile] = useState<File | null>(null)
  const [uploading, setUploading] = useState(false)
  const [analysisId, setAnalysisId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [progress, setProgress] = useState(0)
  const navigate = useNavigate()

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setFile(e.target.files[0])
      setError(null)
    }
  }

  const handleUpload = async () => {
    if (!file) {
      setError('Please select a file')
      return
    }

    setUploading(true)
    setError(null)
    setProgress(0)

    try {
      const formData = new FormData()
      formData.append('file', file)
      formData.append('view_type', 'front')

      const xhr = new XMLHttpRequest()

      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable) {
          const percentComplete = (e.loaded / e.total) * 100
          setProgress(percentComplete)
        }
      })

      const uploadPromise = new Promise<string>((resolve, reject) => {
        xhr.onload = () => {
          if (xhr.status === 200) {
            const response = JSON.parse(xhr.responseText)
            resolve(response.analysis_id)
          } else {
            reject(new Error(`Upload failed: ${xhr.statusText}`))
          }
        }

        xhr.onerror = () => {
          reject(new Error('Network error'))
        }

        xhr.open('POST', `${API_URL}/api/v1/analysis/upload`)
        xhr.send(formData)
      })

      const id = await uploadPromise
      setAnalysisId(id)
      setProgress(100)

      // Navigate to medical dashboard with analysis ID
      setTimeout(() => {
        navigate(`/medical?analysisId=${id}`)
      }, 2000)
    } catch (err: any) {
      setError(err.message || 'Upload failed. Please try again.')
      setUploading(false)
      setProgress(0)
    }
  }

  return (
    <div className="upload-page">
      <h2>Upload Video</h2>
      <p className="description">
        Upload a video file for gait analysis. Supported formats: MP4, AVI, MOV, MKV
      </p>

      <div className="upload-section">
        <input
          type="file"
          accept="video/*"
          onChange={handleFileChange}
          disabled={uploading}
          className="file-input"
        />

        {file && (
          <div className="file-info">
            <p><strong>Selected file:</strong> {file.name}</p>
            <p><strong>Size:</strong> {(file.size / (1024 * 1024)).toFixed(2)} MB</p>
            <p><strong>Type:</strong> {file.type}</p>
          </div>
        )}

        {error && (
          <div className="error">
            {error}
          </div>
        )}

        {uploading && (
          <div className="progress-container">
            <div className="progress-bar-wrapper">
              <div
                className="progress-bar"
                style={{ width: `${progress}%` }}
              />
            </div>
            <p className="progress-text">Uploading... {Math.round(progress)}%</p>
          </div>
        )}

        {analysisId && (
          <div className="success">
            <p>✅ Upload successful!</p>
            <p>Analysis ID: <strong>{analysisId}</strong></p>
            <p>Redirecting to dashboard...</p>
          </div>
        )}

        <button
          onClick={handleUpload}
          disabled={!file || uploading}
          className="btn btn-primary"
          style={{ marginTop: '1rem' }}
        >
          {uploading ? 'Uploading...' : 'Upload and Analyze'}
        </button>
      </div>
    </div>
  )
}
