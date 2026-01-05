# Gait Analysis Application - Azure Platform

A comprehensive gait analysis system that transforms basic RGB video into clinical-grade biomechanical metrics for fall risk assessment and mobility monitoring in older adults.

## Architecture Overview

This application implements a hybrid pipeline that bridges 2D video pixels to 3D biomechanical analysis:

1. **Perception Stack**: High-fidelity pose estimation (HRNet/ViTPose)
2. **3D Uplifting**: Temporal transformer/T-GCN for 2D→3D conversion
3. **Multi-View Fusion**: View-invariant feature extraction with SMPL-X
4. **Environmental Robustness**: Scale calibration and denoising
5. **Metric Calculation**: Clinical priority biomarkers
6. **Multi-Audience Reporting**: Medical professionals, caregivers, older adults

## Key Features

- **Gold Standard Equivalence**: Validated against IR-marker systems (target ICC ≥ 0.85)
- **Clinical Metrics**: Gait speed, stride variability, double support time, step asymmetry, knee/toe clearance
- **Multi-Audience Reports**: Technical dossiers, monitoring dashboards, intuitive summaries
- **Quality Gating**: Fail-safe mechanisms with confidence thresholds
- **Azure Integration**: Scalable cloud infrastructure

## Project Structure

```
Gait-Analysis/
├── backend/                 # FastAPI backend service
├── frontend/                # React dashboard
├── ml_models/              # ML model implementations
├── azure/                  # Azure infrastructure configs
├── tests/                  # Test suite
└── docs/                   # Documentation
```

## Getting Started

### Prerequisites

- Python 3.9+
- Node.js 18+
- Azure account with appropriate services configured
- CUDA-capable GPU (recommended for ML inference)

### Installation

```bash
# Backend setup
cd backend
pip install -r requirements.txt

# Frontend setup
cd frontend
npm install

# Azure deployment
cd azure
az deployment group create --resource-group <your-rg> --template-file main.bicep
```

## Clinical Metrics

| Parameter | Priority | Functional Implication |
|-----------|----------|------------------------|
| Gait Speed | High | 6th Vital Sign; predictor of hospitalization |
| Stride Variability | High | Motor control deterioration; fall-risk signal |
| Double Support Time | Medium | Fear of falling; postural instability |
| Step Asymmetry | Medium | Unilateral pain/weakness indicator |
| Knee/Toe Clearance | High | Trip risk identification |

## Validation Roadmap

1. **Phase 1**: Synchronized trials vs. IR-marker systems (ICC ≥ 0.85)
2. **Phase 2**: In-the-wild robustness testing
3. **Phase 3**: Prospective clinical validation (6-12 months)

## License

Proprietary - Clinical Research Application

