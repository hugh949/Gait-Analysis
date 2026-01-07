#!/bin/bash
# Startup script that ensures Oryx build runs if dependencies aren't installed

set -e

echo "🚀 Starting Gait Analysis Backend..."
echo "===================================="

# Check if virtual environment exists
if [ ! -d "/home/site/wwwroot/antenv" ]; then
  echo "⚠️  Virtual environment not found - triggering Oryx build..."
  echo "   This will install all packages from requirements.txt (including torch)"
  echo "   This may take 5-10 minutes on first run..."
  
  # Run Oryx build
  oryx build /home/site/wwwroot -o /home/site/wwwroot --platform python --platform-version 3.11
  
  if [ $? -eq 0 ]; then
    echo "✅ Oryx build completed successfully"
  else
    echo "❌ Oryx build failed - trying to continue anyway"
  fi
else
  echo "✅ Virtual environment found - skipping build"
fi

# Activate virtual environment if it exists
if [ -d "/home/site/wwwroot/antenv" ]; then
  echo "📦 Activating virtual environment..."
  source /home/site/wwwroot/antenv/bin/activate
  export PATH="/home/site/wwwroot/antenv/bin:$PATH"
fi

# Check if uvicorn is available
if ! command -v uvicorn &> /dev/null; then
  echo "⚠️  uvicorn not found - dependencies not installed!"
  echo "   Oryx should have installed them during deployment."
  echo "   Trying to install minimal dependencies..."
  
  # Install just uvicorn and fastapi to get the app running
  pip install --user uvicorn[standard] fastapi python-multipart || {
    echo "❌ Failed to install uvicorn - exiting"
    exit 1
  }
  
  # Add to PATH
  export PATH="/root/.local/bin:$PATH"
fi

# Verify uvicorn is now available
if ! command -v uvicorn &> /dev/null; then
  echo "❌ uvicorn still not found after installation attempt"
  echo "   Checking Python path..."
  which python3
  python3 -m pip list | grep uvicorn || echo "   uvicorn not in pip list"
  exit 1
fi

# Start the application
echo "🚀 Starting uvicorn server..."
echo "   Uvicorn path: $(which uvicorn)"
echo "   Python path: $(which python3)"
exec uvicorn main:app --host 0.0.0.0 --port 8000
