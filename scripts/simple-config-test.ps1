# Simple Configuration Test for BitFlow External Service Integrations

Write-Host "BitFlow Configuration Test" -ForegroundColor Blue
Write-Host "=========================" -ForegroundColor Blue
Write-Host ""

$passed = 0
$failed = 0

# Test 1: Atomiq Bridge Security Configuration
Write-Host "Testing Atomiq Bridge Security..." -NoNewline
try {
    $atomiq = Get-Content "config/atomiq-bridge.json" | ConvertFrom-Json
    if ($atomiq.production.security.requireApiKey -and $atomiq.production.security.requireSignature) {
        Write-Host " PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host " FAIL" -ForegroundColor Red
        $failed++
    }
} catch {
    Write-Host " ERROR" -ForegroundColor Red
    $failed++
}

# Test 2: DeFi Risk Management
Write-Host "Testing DeFi Risk Management..." -NoNewline
try {
    $defi = Get-Content "config/defi-protocols.json" | ConvertFrom-Json
    if ($defi.riskManagement.enabled) {
        Write-Host " PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host " FAIL" -ForegroundColor Red
        $failed++
    }
} catch {
    Write-Host " ERROR" -ForegroundColor Red
    $failed++
}

# Test 3: API Security Features
Write-Host "Testing API Security Features..." -NoNewline
try {
    $security = Get-Content "config/api-security.json" | ConvertFrom-Json
    if ($security.ddosProtection.enabled -and $security.waf.enabled) {
        Write-Host " PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host " FAIL" -ForegroundColor Red
        $failed++
    }
} catch {
    Write-Host " ERROR" -ForegroundColor Red
    $failed++
}

# Test 4: Monitoring Alerts
Write-Host "Testing Monitoring Alerts..." -NoNewline
try {
    $monitoring = Get-Content "config/monitoring-alerts.json" | ConvertFrom-Json
    $enabledChannels = 0
    if ($monitoring.alerting.channels.slack.enabled) { $enabledChannels++ }
    if ($monitoring.alerting.channels.email.enabled) { $enabledChannels++ }
    if ($monitoring.alerting.channels.pagerduty.enabled) { $enabledChannels++ }
    
    if ($enabledChannels -ge 2) {
        Write-Host " PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host " FAIL" -ForegroundColor Red
        $failed++
    }
} catch {
    Write-Host " ERROR" -ForegroundColor Red
    $failed++
}

# Test 5: External Services Circuit Breaker
Write-Host "Testing External Services Circuit Breaker..." -NoNewline
try {
    $external = Get-Content "config/external-services.json" | ConvertFrom-Json
    if ($external.circuit_breakers.global.enabled) {
        Write-Host " PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host " FAIL" -ForegroundColor Red
        $failed++
    }
} catch {
    Write-Host " ERROR" -ForegroundColor Red
    $failed++
}

# Test 6: System Monitoring
Write-Host "Testing System Monitoring..." -NoNewline
try {
    $system = Get-Content "config/system-monitoring.json" | ConvertFrom-Json
    if ($system.collectors.prometheus.enabled -and $system.collectors.grafana.enabled) {
        Write-Host " PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host " FAIL" -ForegroundColor Red
        $failed++
    }
} catch {
    Write-Host " ERROR" -ForegroundColor Red
    $failed++
}

# Test 7: Production Environment
Write-Host "Testing Production Environment..." -NoNewline
try {
    $prod = Get-Content "config/production-environment.json" | ConvertFrom-Json
    if ($prod.infrastructure.autoscaling.enabled -and $prod.security.encryption.atRest.enabled) {
        Write-Host " PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host " FAIL" -ForegroundColor Red
        $failed++
    }
} catch {
    Write-Host " ERROR" -ForegroundColor Red
    $failed++
}

# Summary
Write-Host ""
Write-Host "Test Results:" -ForegroundColor Blue
Write-Host "============" -ForegroundColor Blue
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red

$total = $passed + $failed
if ($total -gt 0) {
    $successRate = [math]::Round(($passed / $total) * 100, 1)
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } else { "Yellow" })
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "✓ All tests passed! External service integrations are properly configured." -ForegroundColor Green
} else {
    Write-Host "⚠ Some tests failed. Configuration may need review." -ForegroundColor Yellow
}

# Additional validation
Write-Host ""
Write-Host "Configuration File Validation:" -ForegroundColor Blue
Write-Host "=============================" -ForegroundColor Blue

$configFiles = @(
    "config/atomiq-bridge.json",
    "config/defi-protocols.json", 
    "config/api-security.json",
    "config/monitoring-alerts.json",
    "config/external-services.json",
    "config/system-monitoring.json",
    "config/production-environment.json"
)

foreach ($file in $configFiles) {
    Write-Host -NoNewline "Validating $file... "
    if (Test-Path $file) {
        try {
            Get-Content $file | ConvertFrom-Json | Out-Null
            Write-Host "VALID" -ForegroundColor Green
        } catch {
            Write-Host "INVALID JSON" -ForegroundColor Red
        }
    } else {
        Write-Host "MISSING" -ForegroundColor Red
    }
}