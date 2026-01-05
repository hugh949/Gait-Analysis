import { ReactNode } from 'react'
import { Link, useLocation } from 'react-router-dom'
import './Layout.css'

interface LayoutProps {
  children: ReactNode
  selectedAudience: string
  setSelectedAudience: (audience: string) => void
}

export default function Layout({ children, setSelectedAudience }: LayoutProps) {
  const location = useLocation()

  return (
    <div className="layout">
      <header className="header">
        <div className="header-content">
          <h1>Gait Analysis Platform</h1>
          <nav className="nav">
            <Link 
              to="/" 
              className={location.pathname === '/' ? 'active' : ''}
              onClick={() => setSelectedAudience('home')}
            >
              Home
            </Link>
            <Link 
              to="/upload" 
              className={location.pathname === '/upload' ? 'active' : ''}
            >
              Upload Video
            </Link>
            <Link 
              to="/medical" 
              className={location.pathname === '/medical' ? 'active' : ''}
              onClick={() => setSelectedAudience('medical')}
            >
              Medical
            </Link>
            <Link 
              to="/caregiver" 
              className={location.pathname === '/caregiver' ? 'active' : ''}
              onClick={() => setSelectedAudience('caregiver')}
            >
              Caregiver
            </Link>
            <Link 
              to="/older-adult" 
              className={location.pathname === '/older-adult' ? 'active' : ''}
              onClick={() => setSelectedAudience('older-adult')}
            >
              For You
            </Link>
          </nav>
        </div>
      </header>
      <main className="main-content">
        {children}
      </main>
      <footer className="footer">
        <p>Gait Analysis Platform - Clinical-Grade Mobility Monitoring</p>
      </footer>
    </div>
  )
}

