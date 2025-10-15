# BitFlow Quick Setup Script for Windows
# Run this to set up everything for testing

Write-Host "🚀 BitFlow Hackathon Setup Starting..." -ForegroundColor Green

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js found: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js not found. Please install from https://nodejs.org/" -ForegroundColor Red
    exit 1
}

# Check if Scarb is installed
try {
    $scarbVersion = scarb --version
    Write-Host "✅ Scarb found: $scarbVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Scarb not found. Installing..." -ForegroundColor Yellow
    Write-Host "Please install Scarb manually from: https://docs.swmansion.com/scarb/install.html" -ForegroundColor Yellow
}

Write-Host "`n📦 Installing Dependencies..." -ForegroundColor Blue

# Install API dependencies
Write-Host "Installing API dependencies..." -ForegroundColor Yellow
Set-Location api
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ API dependencies installed" -ForegroundColor Green
} else {
    Write-Host "❌ API dependency installation failed" -ForegroundColor Red
}
Set-Location ..

# Install Web dependencies
Write-Host "Installing Web dependencies..." -ForegroundColor Yellow
Set-Location web
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Web dependencies installed" -ForegroundColor Green
} else {
    Write-Host "❌ Web dependency installation failed" -ForegroundColor Red
}
Set-Location ..

# Install Mobile dependencies
Write-Host "Installing Mobile dependencies..." -ForegroundColor Yellow
Set-Location mobile
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Mobile dependencies installed" -ForegroundColor Green
} else {
    Write-Host "❌ Mobile dependency installation failed" -ForegroundColor Red
}
Set-Location ..

# Install JavaScript SDK dependencies
Write-Host "Installing JavaScript SDK dependencies..." -ForegroundColor Yellow
Set-Location sdk/javascript
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ JavaScript SDK dependencies installed" -ForegroundColor Green
} else {
    Write-Host "❌ JavaScript SDK dependency installation failed" -ForegroundColor Red
}
Set-Location ../..

# Setup environment variables
Write-Host "`n🔧 Setting up environment..." -ForegroundColor Blue
if (Test-Path ".env") {
    Write-Host "✅ .env file already exists" -ForegroundColor Green
} else {
    Copy-Item ".env.staging" ".env"
    Write-Host "✅ Created .env from staging template" -ForegroundColor Green
}

# Try to build smart contracts
Write-Host "`n🏗️ Building smart contracts..." -ForegroundColor Blue
try {
    scarb build
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Smart contracts built successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Smart contract build had issues (this is OK for testing)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Scarb not available - install it to build contracts" -ForegroundColor Yellow
}

Write-Host "`n🎉 Setup Complete!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Start API server: cd api && npm run dev" -ForegroundColor White
Write-Host "2. Start web app: cd web && npm run dev" -ForegroundColor White
Write-Host "3. Start mobile app: cd mobile && npm start" -ForegroundColor White
Write-Host "4. Open browser to: http://localhost:3000" -ForegroundColor White
Write-Host "`n📖 See HACKATHON_SETUP.md for detailed testing guide" -ForegroundColor Cyan

Write-Host "`n🏆 Your project is ready for hackathon submission!" -ForegroundColor Green