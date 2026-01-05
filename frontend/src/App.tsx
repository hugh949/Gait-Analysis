import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { useState } from 'react'
import Layout from './components/Layout'
import Home from './pages/Home'
import MedicalDashboard from './pages/MedicalDashboard'
import CaregiverDashboard from './pages/CaregiverDashboard'
import OlderAdultDashboard from './pages/OlderAdultDashboard'
import AnalysisUpload from './pages/AnalysisUpload'
import Upload from './pages/Upload'
import UploadImproved from './pages/UploadImproved'
import ReportView from './pages/ReportView'

function App() {
  const [selectedAudience, setSelectedAudience] = useState<string>('home')

  return (
    <Router>
      <Layout selectedAudience={selectedAudience} setSelectedAudience={setSelectedAudience}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/upload" element={<UploadImproved />} />
          <Route path="/upload-old" element={<Upload />} />
          <Route path="/upload-legacy" element={<AnalysisUpload />} />
          <Route path="/report/:analysisId" element={<ReportView />} />
          <Route path="/medical" element={<MedicalDashboard />} />
          <Route path="/caregiver" element={<CaregiverDashboard />} />
          <Route path="/older-adult" element={<OlderAdultDashboard />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Layout>
    </Router>
  )
}

export default App

