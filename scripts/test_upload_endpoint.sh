#!/bin/bash
# Test script to verify upload endpoint is accessible

BASE_URL="${1:-https://gaitanalysisapp.azurewebsites.net}"

echo "Testing upload endpoint at: ${BASE_URL}"
echo ""

# Test 1: Health check
echo "1. Testing health endpoint..."
curl -s -o /dev/null -w "Status: %{http_code}\n" "${BASE_URL}/api/v1/health"
echo ""

# Test 2: Test endpoint
echo "2. Testing /api/v1/analysis/test endpoint..."
curl -s -w "\nStatus: %{http_code}\n" "${BASE_URL}/api/v1/analysis/test"
echo ""

# Test 3: Diagnostics endpoint
echo "3. Testing /api/v1/analysis/diagnostics endpoint..."
curl -s -w "\nStatus: %{http_code}\n" "${BASE_URL}/api/v1/analysis/diagnostics" | head -50
echo ""

# Test 4: Debug routes endpoint
echo "4. Testing /api/v1/debug/routes endpoint..."
curl -s -w "\nStatus: %{http_code}\n" "${BASE_URL}/api/v1/debug/routes" | head -50
echo ""

# Test 5: Try upload endpoint (should return 400 for missing file, not 404)
echo "5. Testing /api/v1/analysis/upload endpoint (expecting 400 for missing file, not 404)..."
UPLOAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/analysis/upload")
echo "Status: ${UPLOAD_STATUS}"
if [ "${UPLOAD_STATUS}" = "404" ]; then
    echo "❌ ERROR: Upload endpoint returns 404 - route is not registered!"
elif [ "${UPLOAD_STATUS}" = "400" ] || [ "${UPLOAD_STATUS}" = "422" ]; then
    echo "✅ Upload endpoint exists (returned ${UPLOAD_STATUS} for missing file, which is expected)"
else
    echo "⚠️  Upload endpoint returned ${UPLOAD_STATUS} (unexpected but endpoint exists)"
fi
echo ""

echo "Done!"
