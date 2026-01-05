/**
 * Report View Page - Shows reports for different audiences
 */
/**
 * Report View Page - Redirects to appropriate dashboard
 * This is a redirect component that routes to the correct dashboard
 */
import { useEffect } from 'react'
import { useParams, useSearchParams, useNavigate } from 'react-router-dom'
import './ReportView.css'

type Audience = 'medical' | 'caregiver' | 'older-adult'

export default function ReportView() {
  const { analysisId } = useParams<{ analysisId: string }>()
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const audienceParam = (searchParams.get('audience') || 'medical') as Audience

  useEffect(() => {
    if (!analysisId) {
      navigate('/upload')
      return
    }

    // Redirect to appropriate dashboard with analysis ID in URL
    const audienceRouteMap: Record<Audience, string> = {
      'medical': '/medical',
      'caregiver': '/caregiver',
      'older-adult': '/older-adult',
    }
    
    navigate(`${audienceRouteMap[audienceParam]}?analysisId=${analysisId}`, { replace: true })
  }, [analysisId, audienceParam, navigate])

  return (
    <div className="report-view-loading">
      <p>Redirecting to report...</p>
    </div>
  )
}

