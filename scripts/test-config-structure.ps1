# BitFlow Configuration Structure Test
# Simple test to validate configuration structure and key settings

Write-Host "BitFlow Configuration Structure Test" -ForegroundColor Blue
Write-Host "===================================" -ForegroundColor Blue
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Config {
    param(
        [string]$ConfigFile,
        [string]$TestName,
        [scriptblock]$TestBlock
    )
    
    Write-Host "Testing $TestName..." -ForegroundColor Yellow
    
    try {
        if (Test-Path $ConfigFile) {
            $config = Get-Content $ConfigFile | ConvertFrom-Json
            $result = & $TestBlock $config
            
            if ($result) {
                Write-Host "  ✓ $TestName passed" -ForegroundColor Green
                $script:testsPassed++
            } else {
                Write-Host "  ✗ $TestName failed" -ForegroundColor Red
                $script:testsFailed++
            }
        } else {
            Write-Host "  ✗ Configuration file not found: $ConfigFile" -ForegroundColor Red
            $script:testsFailed++
        }
    }
    catch {
        Write-Host "  ✗ Error testing $TestName`: $($_.Exception.Message)" -ForegroundColor Red
        $script:testsFailed++
    }
}

# Test Atomiq Bridge Configuration
Test-Config "config/atomiq-bridge.json" "Atomiq Bridge Security" {
    param($config)
    return $config.production.security.requireApiKey -and $config.production.security.requireSignature
}

Test-Config "config/atomiq-bridge.json" "Atomiq Circuit Breaker" {
    param($config)
    return $config.production.circuitBreaker.enabled
}

Test-Config "config/atomiq-bridge.json" "Atomiq Load Balancing" {
    param($config)
    return $config.production.loadBalancing.enabled
}

# Test DeFi Protocols Configuration
Test-Config "config/defi-protocols.json" "DeFi Risk Management" {
    param($config)
    return $config.riskManagement.enabled
}

Test-Config "config/defi-protocols.json" "DeFi Emergency Withdrawal" {
    param($config)
    return $config.riskManagement.emergencyWithdrawal.enabled
}

Test-Config "config/defi-protocols.json" "DeFi Protocol Verification" {
    param($config)
    return $config.security.contractVerification.enabled
}

# Test API Security Configuration
Test-Config "config/api-security.json" "API Rate Limiting" {
    param($config)
    return $config.rateLimiting.global.maxRequests -gt 0
}

Test-Config "config/api-security.json" "API DDoS Protection" {
    param($config)
    return $config.ddosProtection.enabled
}

Test-Config "config/api-security.json" "API WAF" {
    param($config)
    return $config.waf.enabled
}

# Test Monitoring Configuration
Test-Config "config/monitoring-alerts.json" "Monitoring Channels" {
    param($config)
    $enabledChannels = 0
    if ($config.alerting.channels.slack.enabled) { $enabledChannels++ }
    if ($config.alerting.channels.email.enabled) { $enabledChannels++ }
    if ($config.alerting.channels.pagerduty.enabled) { $enabledChannels++ }
    return $enabledChannels -ge 2
}

Test-Config "config/monitoring-alerts.json" "Monitoring Escalation" {
    param($config)
    return $config.incidents.escalation.levels.Count -ge 3
}

# Test External Services Configuration
Test-Config "config/external-services.json" "External Services Circuit Breaker" {
    param($config)
    return $config.circuit_breakers.global.enabled
}

Test-Config "config/external-services.json" "External Services Observability" {
    param($config)
    return $config.observability.tracing.enabled -and $config.observability.metrics.enabled
}

# Test System Monitoring Configuration
Test-Config "config/system-monitoring.json" "System Monitoring Stack" {
    param($config)
    $enabledCollectors = 0
    if ($config.collectors.prometheus.enabled) { $enabledCollectors++ }
    if ($config.collectors.grafana.enabled) { $enabledCollectors++ }
    if ($config.collectors.alertmanager.enabled) { $enabledCollectors++ }
    return $enabledCollectors -ge 3
}

Test-Config "config/system-monitoring.json" "System SLA Targets" {
    param($config)
    return $config.sla.targets.availability -ge 99.9
}

# Test Production Environment Configuration
Test-Config "config/production-environment.json" "Production Autoscaling" {
    param($config)
    return $config.infrastructure.autoscaling.enabled
}

Test-Config "config/production-environment.json" "Production Encryption" {
    param($config)
    return $config.security.encryption.atRest.enabled -and $config.security.encryption.inTransit.enabled
}

Test-Config "config/production-environment.json" "Production Backup" {
    param($config)
    return $config.backup.database.crossRegion
}

# Summary
Write-Host ""
Write-Host "Test Summary:" -ForegroundColor Blue
Write-Host "=============" -ForegroundColor Blue
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor Red

$totalTests = $testsPassed + $testsFailed
if ($totalTests -gt 0) {
    $successRate = [math]::Round(($testsPassed / $totalTests) * 100, 1)
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })
}

Write-Host ""
if ($testsFailed -eq 0) {
    Write-Host "✓ All configuration tests passed! External service integrations are properly configured." -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some configuration tests failed. Please review the configuration files." -ForegroundColor Red
    exit 1
}