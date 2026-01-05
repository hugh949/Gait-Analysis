# Quick Test Guide - Gait Analysis App

## 🚀 Quick Start Testing

### Option 1: Test via Web Browser (Recommended)

1. **Open the Application**
   - Go to: **https://gentle-wave-0d4e1d10f.4.azurestaticapps.net**
   - You should see the home page

2. **Upload a Video**
   - Click **"Upload Video"** or **"Start Analysis"**
   - Select a video file (MP4, AVI, MOV, or MKV)
   - Click **"Upload and Analyze"**
   - ⚠️ **First request may take 30-60 seconds** (container scales from zero)

3. **View Results**
   - After upload, you'll get an Analysis ID
   - Use this ID to view results in:
     - **Medical Dashboard**: Technical metrics
     - **Caregiver Dashboard**: Fall risk indicator
     - **Older Adult Dashboard**: Health score

---

### Option 2: Test Backend API (Command Line)

#### Quick Health Check
```bash
curl https://gait-analysis-api-eus2.jollymeadow-b5f64007.eastus2.azurecontainerapps.io/health
```

**Expected**: `{"status":"healthy",...}`

#### Upload a Video
```bash
curl -X POST \
  https://gait-analysis-api-eus2.jollymeadow-b5f64007.eastus2.azurecontainerapps.io/api/v1/analysis/upload \
  -F "file=@/path/to/video.mp4" \
  -F "view_type=front"
```

**Expected**: `{"analysis_id":"...","status":"processing"}`

---

### Option 3: Run Test Script

```bash
cd /Users/hughrashid/Cursor/Gait-Analysis
./test-app.sh
```

This will test:
- ✅ Frontend accessibility
- ✅ Backend health
- ✅ CORS configuration
- ✅ API endpoints

---

## 📍 Application URLs

- **Frontend**: https://gentle-wave-0d4e1d10f.4.azurestaticapps.net
- **Backend**: https://gait-analysis-api-eus2.jollymeadow-b5f64007.eastus2.azurecontainerapps.io

---

## ⚠️ Important Notes

### Container Scaling
- The Container App has `minReplicas: 0` (scales to zero)
- **First request takes 30-60 seconds** to start the container
- Subsequent requests are fast

### CORS Configuration
- CORS is configured for the Static Web App URL
- If you see CORS errors, the container may need to restart with new config

### Video Requirements
- **Formats**: MP4, AVI, MOV, MKV
- **Max Size**: 500MB
- **Content**: Person walking (for realistic testing)

---

## 🔍 Troubleshooting

### If Upload Fails

1. **Check Browser Console** (Press F12)
   - Look for errors in Console tab
   - Check Network tab for failed requests

2. **Wait for Container to Start**
   - First request after idle period takes time
   - Try again after 30-60 seconds

3. **Check Backend Logs**
   ```bash
   az containerapp logs show \
     --name gait-analysis-api-eus2 \
     --resource-group gait-analysis-rg-eus2 \
     --tail 50
   ```

### If Backend Times Out

The container scales from zero. Options:

1. **Wait 30-60 seconds** and try again
2. **Increase min replicas** (costs more):
   ```bash
   az containerapp update \
     --name gait-analysis-api-eus2 \
     --resource-group gait-analysis-rg-eus2 \
     --min-replicas 1
   ```

---

## ✅ Success Indicators

- ✅ Frontend loads in browser
- ✅ Can navigate between pages
- ✅ Upload button works
- ✅ Video upload accepts files
- ✅ Analysis ID is returned
- ✅ Can view results in dashboards

---

## 🎯 Ready to Test!

**Start here**: https://gentle-wave-0d4e1d10f.4.azurestaticapps.net

The application is ready for testing! 🚀

