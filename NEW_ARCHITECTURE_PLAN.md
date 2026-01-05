# 🏗️ New Architecture Plan - Simplified & Reliable

## Overview
Complete rebuild of the Gait Analysis application with a simpler, more reliable architecture and clean, modern design.

## Core Principles

1. **Simplicity First**: Reduce complexity, remove unnecessary abstractions
2. **Reliability**: Use proven, stable technologies and deployment patterns
3. **Clean Design**: Simple, intuitive user interface
4. **Clear Separation**: Well-organized code structure, easy to understand and maintain

## Architecture Decisions

### Backend: Azure App Service + FastAPI
- **Why**: Proven reliability, simpler than Container Apps, better for FastAPI
- **Deployment**: Direct code deployment or Docker container
- **Structure**: Simplified service layer, clear API endpoints

### Frontend: React + TypeScript (Vite)
- **Why**: Modern, fast, well-supported
- **Design**: Clean, simple interface (as per user preference)
- **Styling**: Modern CSS with clean, minimal design

### Storage: Azure Blob Storage + Cosmos DB
- **Videos**: Direct upload to Blob Storage (via SAS tokens)
- **Metadata**: Cosmos DB for analysis results and tracking
- **Simplified**: No complex storage abstractions

## Backend Structure

```
backend/
├── app/
│   ├── api/
│   │   └── routes/
│   │       ├── analysis.py      # Analysis endpoints
│   │       ├── health.py        # Health checks
│   │       └── storage.py       # Blob storage SAS tokens
│   ├── services/
│   │   ├── video_processor.py   # Video processing orchestration
│   │   ├── metrics.py           # Metrics calculation
│   │   └── storage_service.py   # Azure storage operations
│   ├── core/
│   │   ├── config.py            # Configuration
│   │   └── database.py          # Cosmos DB client
│   └── models/
│       └── schemas.py           # Pydantic models
├── main.py                      # FastAPI app
└── requirements.txt
```

### Key Simplifications

1. **Direct Upload Pattern**:
   - Frontend gets SAS token from backend
   - Frontend uploads directly to Blob Storage
   - Frontend triggers processing via API
   - Backend processes from blob storage

2. **Simplified Service Layer**:
   - Clear, single-responsibility services
   - No over-engineering
   - Easy to test and debug

3. **Configuration**:
   - Environment variables
   - Simple settings class
   - No complex validation

## Frontend Structure

```
frontend/
├── src/
│   ├── components/
│   │   ├── Layout/
│   │   ├── Upload/
│   │   ├── Dashboard/
│   │   └── Metrics/
│   ├── pages/
│   │   ├── Home.tsx
│   │   ├── Upload.tsx
│   │   └── Dashboard.tsx
│   ├── services/
│   │   ├── api.ts              # API client
│   │   └── storage.ts          # Blob storage client
│   ├── types/
│   │   └── index.ts            # TypeScript types
│   └── styles/
│       └── globals.css         # Global styles
```

### Design Principles

1. **Clean & Simple**: Minimal, intuitive interface
2. **Clear Navigation**: Easy to understand flows
3. **Responsive**: Works on all devices
4. **Accessible**: Following best practices

## API Design

### Endpoints

```
GET  /health                    # Health check
GET  /api/storage/sas-token     # Get SAS token for upload
POST /api/analysis/process      # Trigger processing
GET  /api/analysis/{id}         # Get analysis results
GET  /api/analysis/{id}/report  # Get formatted report
```

### Request/Response Flow

1. **Upload Flow**:
   ```
   Frontend → GET /api/storage/sas-token
   Frontend → Upload video to Blob Storage (direct)
   Frontend → POST /api/analysis/process { blob_name, patient_id }
   Backend → Process video from Blob Storage
   Frontend → Poll GET /api/analysis/{id} for status
   ```

## Deployment

### Backend: Azure App Service
- **Plan**: Basic B1 (or Consumption)
- **Runtime**: Python 3.11
- **Method**: Docker container or direct deployment
- **Environment**: Environment variables for configuration

### Frontend: Azure Static Web Apps
- **Build**: Vite production build
- **Hosting**: Static Web Apps
- **Configuration**: Environment variables for API URL

## Implementation Phases

### Phase 1: Backend Core ✅
- [x] Simplified FastAPI structure
- [x] Health check endpoint
- [x] Configuration management
- [x] Database connection

### Phase 2: Storage Integration
- [ ] Blob Storage SAS token generation
- [ ] Direct upload support
- [ ] Video retrieval from blob storage

### Phase 3: Processing Pipeline
- [ ] Video processing service
- [ ] Metrics calculation
- [ ] Result storage

### Phase 4: Frontend Rebuild
- [ ] Clean, modern design
- [ ] Upload interface
- [ ] Dashboard views
- [ ] API integration

### Phase 5: Testing & Deployment
- [ ] Local testing
- [ ] Azure deployment
- [ ] End-to-end validation

## Migration Strategy

1. **Keep existing code** until new version is validated
2. **Deploy to new endpoints** (avoid breaking existing deployments)
3. **Test thoroughly** before switching over
4. **Gradual migration** of features

## Success Criteria

- ✅ Backend starts reliably
- ✅ Video upload works smoothly
- ✅ Processing completes successfully
- ✅ Frontend displays results clearly
- ✅ Deployment is straightforward
- ✅ Code is maintainable and well-organized

