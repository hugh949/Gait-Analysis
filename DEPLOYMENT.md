# Deployment Guide

## Prerequisites

- Azure account with appropriate permissions
- Azure CLI installed and configured
- Python 3.9+ installed
- Node.js 18+ installed
- Git installed

## Azure Infrastructure Setup

### 1. Create Resource Group

```bash
az group create --name gait-analysis-rg-eus2 --location eastus2
```

### 2. Deploy Infrastructure

```bash
cd azure
az deployment group create \
  --resource-group gait-analysis-rg-eus2 \
  --template-file core-resources-eus2.bicep \
  --parameters appName=gaitanalysis environment=prod location=eastus2
```

### 3. Configure Environment Variables

After deployment, retrieve connection strings and configure:

```bash
# Get storage connection string
az storage account show-connection-string \
  --name <storage-account-name> \
  --resource-group gait-analysis-rg

# Get Cosmos DB keys
az cosmosdb keys list \
  --name <cosmos-account-name> \
  --resource-group gait-analysis-rg
```

Update `.env` file with these values.

## Backend Deployment

### 1. Prepare Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Deploy to Azure App Service

```bash
# Install Azure CLI extension for App Service
az extension add --name webapp

# Create deployment package
zip -r deploy.zip . -x "venv/*" "*.pyc" "__pycache__/*"

# Deploy
az webapp deployment source config-zip \
  --resource-group gait-analysis-rg \
  --name <backend-app-name> \
  --src deploy.zip
```

### 3. Configure App Settings

```bash
az webapp config appsettings set \
  --resource-group gait-analysis-rg \
  --name <backend-app-name> \
  --settings \
    AZURE_STORAGE_CONNECTION_STRING="<connection-string>" \
    AZURE_COSMOS_ENDPOINT="<endpoint>" \
    AZURE_COSMOS_KEY="<key>"
```

## Frontend Deployment

### 1. Build Frontend

```bash
cd frontend
npm install
npm run build
```

### 2. Deploy to Azure App Service

```bash
# Configure for Node.js
az webapp config set \
  --resource-group gait-analysis-rg \
  --name <frontend-app-name> \
  --linux-fx-version "NODE|18-lts"

# Deploy
cd dist
zip -r frontend.zip .
az webapp deployment source config-zip \
  --resource-group gait-analysis-rg \
  --name <frontend-app-name> \
  --src frontend.zip
```

## Model Deployment

### 1. Upload Models to Azure Storage

```bash
az storage blob upload \
  --account-name <storage-account-name> \
  --container-name models \
  --name pose_estimation.pth \
  --file ./models/pose_estimation.pth
```

### 2. Configure Model Paths

Update App Service settings to point to blob storage paths.

## Validation Setup

### Phase 1: Verification

1. Set up synchronized trials with IR-marker systems
2. Run parallel analysis on same videos
3. Calculate Intraclass Correlation Coefficients (target: ICC ≥ 0.85)

### Phase 2: Robustness Testing

1. Test on "in-the-wild" datasets
2. Include home-specific artifacts (pets, loose clothing, low lighting)
3. Validate scale calibration and denoising

### Phase 3: Clinical Validation

1. Prospective study over 6-12 months
2. Correlate Fall Risk Index with real-world fall incidence
3. Validate predictive value

## Monitoring

### Application Insights

```bash
az monitor app-insights component create \
  --app gait-analysis-insights \
  --location eastus \
  --resource-group gait-analysis-rg
```

### Log Analytics

Monitor:
- API response times
- Error rates
- Model inference times
- Quality gate failure rates

## Scaling

### Horizontal Scaling

```bash
az appservice plan update \
  --name <plan-name> \
  --resource-group gait-analysis-rg \
  --sku S1  # Scale up as needed
```

### Auto-scaling

Configure auto-scale rules based on:
- CPU utilization
- Request queue length
- Processing time

## Security

1. Enable HTTPS only
2. Configure CORS properly
3. Use Key Vault for secrets
4. Implement authentication/authorization
5. Enable Azure AD integration

## Backup

### Cosmos DB

```bash
az cosmosdb sql container create \
  --account-name <cosmos-account> \
  --database-name gait-analysis \
  --name backups \
  --partition-key-path "/id"
```

### Storage Account

Enable blob versioning and soft delete.

## Troubleshooting

### Check Logs

```bash
az webapp log tail \
  --name <app-name> \
  --resource-group gait-analysis-rg
```

### Test Endpoints

```bash
curl https://<backend-app-name>.azurewebsites.net/health
```

## Cost Optimization

1. Use Azure Reserved Instances for predictable workloads
2. Enable auto-pause for development environments
3. Use Azure Spot VMs for batch processing
4. Implement caching to reduce compute costs

