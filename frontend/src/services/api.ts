/**
 * API Client for Gait Analysis Backend
 */
import axios from 'axios'

const API_URL = (import.meta as any).env?.VITE_API_URL || 'http://localhost:8000'

const apiClient = axios.create({
  baseURL: `${API_URL}/api/v1`,
  timeout: 300000, // 5 minutes for large uploads
  headers: {
    'Content-Type': 'application/json',
  },
})

export interface SASRequest {
  blob_name: string
  expiry_minutes?: number
}

export interface SASResponse {
  sas_url: string
  blob_name: string
  expiry_minutes: number
}

export interface ProcessRequest {
  blob_name: string
  patient_id?: string
  view_type?: string
  reference_length_mm?: number
  fps?: number
}

export interface ProcessResponse {
  analysis_id: string
  status: string
  message: string
}

export interface AnalysisResult {
  analysis_id: string
  status: string
  patient_id?: string
  metrics?: any
  error?: string
  created_at?: string
}

/**
 * Get SAS token for uploading video to blob storage
 */
export async function getSASToken(blobName: string, expiryMinutes: number = 60): Promise<SASResponse> {
  const response = await apiClient.post<SASResponse>('/storage/sas-token', {
    blob_name: blobName,
    expiry_minutes: expiryMinutes,
  })
  return response.data
}

/**
 * Upload file directly to Azure Blob Storage using SAS URL
 */
export async function uploadToBlobStorage(file: File, sasUrl: string, onProgress?: (progress: number) => void): Promise<void> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()

    xhr.upload.addEventListener('progress', (e) => {
      if (e.lengthComputable && onProgress) {
        const percentComplete = (e.loaded / e.total) * 100
        onProgress(percentComplete)
      }
    })

    xhr.addEventListener('load', () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve()
      } else {
        reject(new Error(`Upload failed with status ${xhr.status}`))
      }
    })

    xhr.addEventListener('error', () => {
      reject(new Error('Upload failed due to network error'))
    })

    xhr.addEventListener('abort', () => {
      reject(new Error('Upload was aborted'))
    })

    xhr.open('PUT', sasUrl)
    xhr.setRequestHeader('x-ms-blob-type', 'BlockBlob')
    xhr.setRequestHeader('Content-Type', file.type)
    xhr.send(file)
  })
}

/**
 * Trigger video analysis processing
 */
export async function processVideo(request: ProcessRequest): Promise<ProcessResponse> {
  const response = await apiClient.post<ProcessResponse>('/analysis/process', request)
  return response.data
}

/**
 * Get analysis results by ID
 */
export async function getAnalysis(analysisId: string): Promise<AnalysisResult> {
  const response = await apiClient.get<AnalysisResult>(`/analysis/${analysisId}`)
  return response.data
}

/**
 * Get report by analysis ID and audience
 */
export async function getReport(analysisId: string, audience: 'medical' | 'caregiver' | 'older_adult'): Promise<any> {
  const response = await apiClient.get(`/reports/${analysisId}?audience=${audience}`)
  return response.data
}

