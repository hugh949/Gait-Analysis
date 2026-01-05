# Deploying with Azure Functions (Alternative to App Service)

Since App Service Plans require quota that's not available, we can use Azure Functions which runs on Consumption plan (serverless, no quota needed).

## Option 1: Azure Functions for Backend

### Create Function App

```bash
# Create storage account for function app (if not using existing)
az storage account create \
  --name gaitanalysisfuncstor \
  --resource-group gait-analysis-rg-eus2 \
  --location eastus2 \
  --sku Standard_LRS

# Create function app
az functionapp create \
  --resource-group gait-analysis-rg-eus2 \
  --consumption-plan-location eastus2 \
  --runtime python \
  --runtime-version 3.11 \
  --functions-version 4 \
  --name gait-analysis-api \
  --storage-account gaitanalysisfuncstor \
  --os-type Linux
```

### Configure Function App Settings

```bash
# Get connection strings
STORAGE_CONN=$(az storage account show-connection-string \
  --name gaitanalysisprodstor \
  --resource-group gait-analysis-rg-eus2 \
  --query connectionString -o tsv)

COSMOS_ENDPOINT=$(az cosmosdb show \
  --name gaitanalysisprodcosmos \
  --resource-group gait-analysis-rg-eus2 \
  --query documentEndpoint -o tsv)

COSMOS_KEY=$(az cosmosdb keys list \
  --name gaitanalysisprodcosmos \
  --resource-group gait-analysis-rg-eus2 \
  --query primaryMasterKey -o tsv)

# Set app settings
az functionapp config appsettings set \
  --resource-group gait-analysis-rg-eus2 \
  --name gait-analysis-api \
  --settings \
    AZURE_STORAGE_CONNECTION_STRING="$STORAGE_CONN" \
    AZURE_COSMOS_ENDPOINT="$COSMOS_ENDPOINT" \
    AZURE_COSMOS_KEY="$COSMOS_KEY" \
    AZURE_COSMOS_DATABASE="gait-analysis-db" \
    AzureWebJobsStorage="$STORAGE_CONN"
```

### Deploy Backend Code

```bash
cd backend
# Install dependencies
pip install -r requirements.txt

# Deploy to function app
func azure functionapp publish gait-analysis-api --python
```

## Option 2: Azure Static Web Apps for Frontend

```bash
# Create static web app
az staticwebapp create \
  --name gait-analysis-web \
  --resource-group gait-analysis-rg-eus2 \
  --location eastus2 \
  --sku Free

# Build and deploy frontend
cd frontend
npm run build
az staticwebapp deploy \
  --name gait-analysis-web \
  --resource-group gait-analysis-rg-eus2 \
  --app-location "./" \
  --output-location "dist"
```

## Option 3: Use Existing Resources + Local Development

For development, you can run the application locally and connect to Azure services:

1. Backend runs locally on `http://localhost:8000`
2. Frontend runs locally on `http://localhost:3000`
3. Both connect to Azure Storage and Cosmos DB

This is the simplest approach for development and testing.

