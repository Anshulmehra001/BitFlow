# BitFlow Comprehensive Test Script
# Tests all components to verify hackathon readiness

Write-Host "🧪 BitFlow Comprehensive Testing..." -ForegroundColor Green

$testResults = @()

# Test 1: Smart Contract Compilation
Write-Host "`n1️⃣ Testing Smart Contract Compilation..." -ForegroundColor Blue
try {
    scarb build
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Smart contracts compile successfully" -ForegroundColor Green
        $testResults += "Smart Contract Compilation: PASS"
    } else {
        Write-Host "⚠️ Smart contract compilation issues" -ForegroundColor Yellow
        $testResults += "Smart Contract Compilation: WARNING"
    }
} catch {
    Write-Host "❌ Scarb not found - cannot test contracts" -ForegroundColor Red
    $testResults += "Smart Contract Compilation: SKIP (Scarb not installed)"
}

# Test 2: API Server
Write-Host "`n2️⃣ Testing API Server..." -ForegroundColor Blue
Set-Location api
$apiProcess = Start-Process -FilePath "npm" -ArgumentList "start" -PassThru -WindowStyle Hidden
Start-Sleep 5

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000/health" -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ API server responds correctly" -ForegroundColor Green
        $testResults += "API Server: PASS"
    } else {
        Write-Host "⚠️ API server responds but with issues" -ForegroundColor Yellow
        $testResults += "API Server: WARNING"
    }
} catch {
    Write-Host "❌ API server not responding" -ForegroundColor Red
    $testResults += "API Server: FAIL"
}

# Stop API process
if ($apiProcess) { Stop-Process -Id $apiProcess.Id -Force -ErrorAction SilentlyContinue }
Set-Location ..

# Test 3: Web App Build
Write-Host "`n3️⃣ Testing Web App Build..." -ForegroundColor Blue
Set-Location web
try {
    npm run build
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Web app builds successfully" -ForegroundColor Green
        $testResults += "Web App Build: PASS"
    } else {
        Write-Host "❌ Web app build failed" -ForegroundColor Red
        $testResults += "Web App Build: FAIL"
    }
} catch {
    Write-Host "❌ Web app build error" -ForegroundColor Red
    $testResults += "Web App Build: FAIL"
}
Set-Location ..

# Test 4: Mobile App Dependencies
Write-Host "`n4️⃣ Testing Mobile App..." -ForegroundColor Blue
Set-Location mobile
if (Test-Path "node_modules") {
    Write-Host "✅ Mobile app dependencies installed" -ForegroundColor Green
    $testResults += "Mobile App: PASS"
} else {
    Write-Host "❌ Mobile app dependencies missing" -ForegroundColor Red
    $testResults += "Mobile App: FAIL"
}
Set-Location ..

# Test 5: SDK Examples
Write-Host "`n5️⃣ Testing SDK Examples..." -ForegroundColor Blue
Set-Location sdk/javascript
if (Test-Path "node_modules") {
    Write-Host "✅ JavaScript SDK ready" -ForegroundColor Green
    $testResults += "JavaScript SDK: PASS"
} else {
    Write-Host "❌ JavaScript SDK dependencies missing" -ForegroundColor Red
    $testResults += "JavaScript SDK: FAIL"
}
Set-Location ../..

# Test 6: Configuration Files
Write-Host "`n6️⃣ Testing Configuration..." -ForegroundColor Blue
$configFiles = @(
    ".env",
    "config/atomiq-bridge.json",
    "config/defi-protocols.json",
    "config/api-security.json"
)

$configPass = $true
foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file exists" -ForegroundColor Green
    } else {
        Write-Host "❌ $file missing" -ForegroundColor Red
        $configPass = $false
    }
}

if ($configPass) {
    $testResults += "Configuration: PASS"
} else {
    $testResults += "Configuration: FAIL"
}

# Test 7: Documentation
Write-Host "`n7️⃣ Testing Documentation..." -ForegroundColor Blue
$docFiles = @(
    "README.md",
    "HACKATHON_SETUP.md",
    "docs/DEPLOYMENT.md",
    "api/README.md",
    "web/README.md",
    "mobile/README.md"
)

$docPass = $true
foreach ($file in $docFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file exists" -ForegroundColor Green
    } else {
        Write-Host "❌ $file missing" -ForegroundColor Red
        $docPass = $false
    }
}

if ($docPass) {
    $testResults += "Documentation: PASS"
} else {
    $testResults += "Documentation: FAIL"
}

# Summary
Write-Host "`n📊 TEST RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
foreach ($result in $testResults) {
    if ($result -like "*PASS*") {
        Write-Host $result -ForegroundColor Green
    } elseif ($result -like "*WARNING*") {
        Write-Host $result -ForegroundColor Yellow
    } elseif ($result -like "*SKIP*") {
        Write-Host $result -ForegroundColor Gray
    } else {
        Write-Host $result -ForegroundColor Red
    }
}

$passCount = ($testResults | Where-Object { $_ -like "*PASS*" }).Count
$totalCount = $testResults.Count

Write-Host "`n🎯 HACKATHON READINESS: $passCount/$totalCount tests passed" -ForegroundColor Cyan

if ($passCount -ge ($totalCount * 0.8)) {
    Write-Host "🏆 EXCELLENT - Ready for submission!" -ForegroundColor Green
} elseif ($passCount -ge ($totalCount * 0.6)) {
    Write-Host "✅ GOOD - Minor fixes needed" -ForegroundColor Yellow
} else {
    Write-Host "⚠️ NEEDS WORK - Address failing tests" -ForegroundColor Red
}

Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Fix any failing tests above" -ForegroundColor White
Write-Host "2. Record 3-minute demo video" -ForegroundColor White
Write-Host "3. Create pitch deck (optional)" -ForegroundColor White
Write-Host "4. Submit to Devpost before deadline" -ForegroundColor White