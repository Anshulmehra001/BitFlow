# BitFlow Quick Setup
Write-Host "BitFlow Hackathon Setup Starting..." -ForegroundColor Green

# Check Node.js
try {
    $nodeVersion = node --version
    Write-Host "Node.js found: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "Node.js not found. Install from https://nodejs.org/" -ForegroundColor Red
    exit 1
}

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Blue

# API
Write-Host "Installing API dependencies..."
Set-Location api
npm install
Set-Location ..

# Web
Write-Host "Installing Web dependencies..."
Set-Location web  
npm install
Set-Location ..

# Mobile
Write-Host "Installing Mobile dependencies..."
Set-Location mobile
npm install
Set-Location ..

# SDK
Write-Host "Installing SDK dependencies..."
Set-Location sdk/javascript
npm install
Set-Location ../..

# Setup environment
if (-not (Test-Path ".env")) {
    Copy-Item ".env.staging" ".env"
    Write-Host "Created .env file" -ForegroundColor Green
}

Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "Next: Start API with 'cd api && npm run dev'" -ForegroundColor Cyan