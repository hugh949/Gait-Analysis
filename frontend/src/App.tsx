import { useState } from 'react'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import AnalysisUpload from './pages/AnalysisUpload'

function App() {
  const [selectedAudience, setSelectedAudience] = useState('home')

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={
          <Layout selectedAudience={selectedAudience} setSelectedAudience={setSelectedAudience}>
            <Home />
          </Layout>
        } />
        <Route path="/upload" element={
          <Layout selectedAudience={selectedAudience} setSelectedAudience={setSelectedAudience}>
            <AnalysisUpload />
          </Layout>
        } />
        <Route path="/medical" element={
          <Layout selectedAudience={selectedAudience} setSelectedAudience={setSelectedAudience}>
            <div className="dashboard">
              <h2>Medical Dashboard</h2>
              <p>Medical dashboard coming soon...</p>
            </div>
          </Layout>
        } />
        <Route path="/caregiver" element={
          <Layout selectedAudience={selectedAudience} setSelectedAudience={setSelectedAudience}>
            <div className="dashboard">
              <h2>Caregiver Dashboard</h2>
              <p>Caregiver dashboard coming soon...</p>
            </div>
          </Layout>
        } />
        <Route path="/older-adult" element={
          <Layout selectedAudience={selectedAudience} setSelectedAudience={setSelectedAudience}>
            <div className="dashboard">
              <h2>Older Adult Dashboard</h2>
              <p>Older adult dashboard coming soon...</p>
            </div>
          </Layout>
        } />
      </Routes>
    </BrowserRouter>
  )
}

export default App
