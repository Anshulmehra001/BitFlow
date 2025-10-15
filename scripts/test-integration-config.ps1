# BitFlow Integration Configuration Test Script
# This script tests the configuration structure and integration logic

param(
    [string]$Environment = "production",
    [string]$ConfigDir = "config"
)

$TestResults = @()

Write-Host "BitFlow Integration Configuration Test" -ForegroundColor Blue
Write-Host "=====================================" -ForegroundColor Blue
Write-Host ""

function Add-TestResult {
    param(
        [string]$Status,
        [string]$Test,
        [string]$Message
    )
    
    $script:TestResults += [PSCustomObject]@{
        Status = $Status
        Test = $Test
        Message = $Message
    }
}

function Test-AtomiqBridgeConfig {
    Write-Host "Testing Atomiq Bridge Configuration..." -ForegroundColor Yellow
    
    try {
        $config = Get-Content "$ConfigDir/atomiq-bridge.json" | ConvertFrom-Json
        
        # Test production configuration exists
        if ($config.production) {
            Write-Host "  ✓ Production configuration exists" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Atomiq Production Config" -Message "Configuration exists"
        } else {
            Write-Host "  ✗ Production configuration missing" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "Atomiq Production Config" -Message "Configuration missing"
        }
        
        # Test security settings
        if ($config.production.security.requireApiKey -and $config.production.security.requireSignature) {
            Write-Host "  ✓ Security settings properly configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Atomiq Security" -Message "API key and signature required"
        } else {
            Write-Host "  ✗ Security settings incomplete" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "Atomiq Security" -Message "Missing security requirements"
        }
        
        # Test circuit breaker
        if ($config.production.circuitBreaker.enabled) {
            Write-Host "  ✓ Circuit breaker enabled" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Atomiq Circuit Breaker" -Message "Enabled with threshold $($config.production.circuitBreaker.failureThreshold)"
        } else {
            Write-Host "  ✗ Circuit breaker disabled" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "Atomiq Circuit Breaker" -Message "Circuit breaker not enabled"
        }
        
        # Test load balancing
        if ($config.production.loadBalancing.enabled -and $config.production.loadBalancing.endpoints.Count -gt 1) {
            Write-Host "  ✓ Load balancing configured with multiple endpoints" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Atomiq Load Balancing" -Message "$($config.production.loadBalancing.endpoints.Count) endpoints configured"
        } else {
            Write-Host "  ⚠ Load balancing not fully configured" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Atomiq Load Balancing" -Message "Single endpoint or disabled"
        }
        
    }
    catch {
        Write-Host "  ✗ Error reading Atomiq configuration: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult -Status "FAIL" -Test "Atomiq Config Read" -Message $_.Exception.Message
    }
}

function Test-DefiProtocolsConfig {
    Write-Host "Testing DeFi Protocols Configuration..." -ForegroundColor Yellow
    
    try {
        $config = Get-Content "$ConfigDir/defi-protocols.json" | ConvertFrom-Json
        
        # Test all protocols exist
        $protocols = @("vesu", "troves", "endurfi")
        foreach ($protocol in $protocols) {
            if ($config.$protocol.production) {
                Write-Host "  ✓ $protocol production configuration exists" -ForegroundColor Green
                Add-TestResult -Status "PASS" -Test "$protocol Config" -Message "Production configuration exists"
            } else {
                Write-Host "  ✗ $protocol production configuration missing" -ForegroundColor Red
                Add-TestResult -Status "FAIL" -Test "$protocol Config" -Message "Production configuration missing"
            }
        }
        
        # Test risk management
        if ($config.riskManagement.enabled) {
            Write-Host "  ✓ Risk management enabled" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "DeFi Risk Management" -Message "Enabled with max exposure $($config.riskManagement.maxExposurePerProtocol)"
        } else {
            Write-Host "  ✗ Risk management disabled" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "DeFi Risk Management" -Message "Risk management not enabled"
        }
        
        # Test emergency withdrawal
        if ($config.riskManagement.emergencyWithdrawal.enabled) {
            Write-Host "  ✓ Emergency withdrawal configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Emergency Withdrawal" -Message "$($config.riskManagement.emergencyWithdrawal.triggers.Count) triggers configured"
        } else {
            Write-Host "  ✗ Emergency withdrawal not configured" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "Emergency Withdrawal" -Message "Emergency withdrawal not enabled"
        }
        
        # Test yield strategies
        if ($config.yieldStrategy.strategies.Count -ge 3) {
            Write-Host "  ✓ Multiple yield strategies configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Yield Strategies" -Message "$($config.yieldStrategy.strategies.PSObject.Properties.Count) strategies available"
        } else {
            Write-Host "  ⚠ Limited yield strategies" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Yield Strategies" -Message "Few strategies configured"
        }
        
    }
    catch {
        Write-Host "  ✗ Error reading DeFi configuration: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult -Status "FAIL" -Test "DeFi Config Read" -Message $_.Exception.Message
    }
}

function Test-ApiSecurityConfig {
    Write-Host "Testing API Security Configuration..." -ForegroundColor Yellow
    
    try {
        $config = Get-Content "$ConfigDir/api-security.json" | ConvertFrom-Json
        
        # Test rate limiting
        if ($config.rateLimiting.global.maxRequests -gt 0) {
            Write-Host "  ✓ Global rate limiting configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Global Rate Limiting" -Message "$($config.rateLimiting.global.maxRequests) requests per window"
        } else {
            Write-Host "  ✗ Global rate limiting not configured" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "Global Rate Limiting" -Message "No rate limiting configured"
        }
        
        # Test distributed rate limiting
        if ($config.rateLimiting.distributed.enabled) {
            Write-Host "  ✓ Distributed rate limiting enabled" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Distributed Rate Limiting" -Message "Using $($config.rateLimiting.distributed.store) store"
        } else {
            Write-Host "  ⚠ Distributed rate limiting disabled" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Distributed Rate Limiting" -Message "Not using distributed store"
        }
        
        # Test DDoS protection
        if ($config.ddosProtection.enabled) {
            Write-Host "  ✓ DDoS protection enabled" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "DDoS Protection" -Message "Threshold: $($config.ddosProtection.thresholds.requestsPerSecond) req/sec"
        } else {
            Write-Host "  ✗ DDoS protection disabled" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "DDoS Protection" -Message "DDoS protection not enabled"
        }
        
        # Test WAF
        if ($config.waf.enabled) {
            Write-Host "  ✓ Web Application Firewall enabled" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "WAF" -Message "WAF enabled with custom rules"
        } else {
            Write-Host "  ✗ Web Application Firewall disabled" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "WAF" -Message "WAF not enabled"
        }
        
        # Test CORS configuration
        if ($config.cors.production.origin.Count -gt 0) {
            Write-Host "  ✓ CORS properly configured for production" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "CORS Production" -Message "$($config.cors.production.origin.Count) allowed origins"
        } else {
            Write-Host "  ✗ CORS not configured for production" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "CORS Production" -Message "No allowed origins configured"
        }
        
    }
    catch {
        Write-Host "  ✗ Error reading API security configuration: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult -Status "FAIL" -Test "API Security Config Read" -Message $_.Exception.Message
    }
}

function Test-MonitoringConfig {
    Write-Host "Testing Monitoring Configuration..." -ForegroundColor Yellow
    
    try {
        $config = Get-Content "$ConfigDir/monitoring-alerts.json" | ConvertFrom-Json
        
        # Test alerting channels
        $channels = @("slack", "email", "pagerduty", "webhook")
        $enabledChannels = 0
        foreach ($channel in $channels) {
            if ($config.alerting.channels.$channel.enabled) {
                $enabledChannels++
            }
        }
        
        if ($enabledChannels -ge 2) {
            Write-Host "  ✓ Multiple alerting channels configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Alert Channels" -Message "$enabledChannels channels enabled"
        } else {
            Write-Host "  ⚠ Limited alerting channels" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Alert Channels" -Message "Only $enabledChannels channels enabled"
        }
        
        # Test escalation levels
        if ($config.incidents.escalation.levels.Count -ge 3) {
            Write-Host "  ✓ Multi-level escalation configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Escalation Levels" -Message "$($config.incidents.escalation.levels.Count) escalation levels"
        } else {
            Write-Host "  ⚠ Limited escalation levels" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Escalation Levels" -Message "Few escalation levels configured"
        }
        
        # Test health checks
        $healthChecks = @("api", "database", "redis", "starknet", "atomiqBridge")
        $configuredChecks = 0
        foreach ($check in $healthChecks) {
            if ($config.healthChecks.$check) {
                $configuredChecks++
            }
        }
        
        if ($configuredChecks -ge 4) {
            Write-Host "  ✓ Comprehensive health checks configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Health Checks" -Message "$configuredChecks health checks configured"
        } else {
            Write-Host "  ⚠ Limited health checks" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Health Checks" -Message "Only $configuredChecks health checks configured"
        }
        
        # Test thresholds
        $thresholdCategories = @("api", "streams", "bridge", "yield", "system", "security", "business")
        $configuredThresholds = 0
        foreach ($category in $thresholdCategories) {
            if ($config.thresholds.$category) {
                $configuredThresholds++
            }
        }
        
        if ($configuredThresholds -eq $thresholdCategories.Count) {
            Write-Host "  ✓ All monitoring thresholds configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Monitoring Thresholds" -Message "All $configuredThresholds categories configured"
        } else {
            Write-Host "  ⚠ Some monitoring thresholds missing" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Monitoring Thresholds" -Message "$configuredThresholds/$($thresholdCategories.Count) categories configured"
        }
        
    }
    catch {
        Write-Host "  ✗ Error reading monitoring configuration: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult -Status "FAIL" -Test "Monitoring Config Read" -Message $_.Exception.Message
    }
}

function Test-ExternalServicesConfig {
    Write-Host "Testing External Services Configuration..." -ForegroundColor Yellow
    
    try {
        $config = Get-Content "$ConfigDir/external-services.json" | ConvertFrom-Json
        
        # Test service definitions
        $requiredServices = @("atomiq_bridge", "vesu_protocol", "troves_protocol", "starknet_rpc")
        $configuredServices = 0
        foreach ($service in $requiredServices) {
            if ($config.services.$service) {
                $configuredServices++
            }
        }
        
        if ($configuredServices -eq $requiredServices.Count) {
            Write-Host "  ✓ All required services configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Required Services" -Message "All $configuredServices services configured"
        } else {
            Write-Host "  ✗ Missing required services" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "Required Services" -Message "$configuredServices/$($requiredServices.Count) services configured"
        }
        
        # Test circuit breakers
        if ($config.circuit_breakers.global.enabled) {
            Write-Host "  ✓ Global circuit breaker enabled" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Global Circuit Breaker" -Message "Enabled with threshold $($config.circuit_breakers.global.failure_threshold)"
        } else {
            Write-Host "  ✗ Global circuit breaker disabled" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "Global Circuit Breaker" -Message "Circuit breaker not enabled"
        }
        
        # Test service mesh
        if ($config.service_mesh.enabled) {
            Write-Host "  ✓ Service mesh enabled" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Service Mesh" -Message "Using $($config.service_mesh.provider)"
        } else {
            Write-Host "  ⚠ Service mesh disabled" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Service Mesh" -Message "Service mesh not enabled"
        }
        
        # Test observability
        if ($config.observability.tracing.enabled -and $config.observability.metrics.enabled) {
            Write-Host "  ✓ Observability fully configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Observability" -Message "Tracing and metrics enabled"
        } else {
            Write-Host "  ⚠ Observability partially configured" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Observability" -Message "Some observability features disabled"
        }
        
    }
    catch {
        Write-Host "  ✗ Error reading external services configuration: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult -Status "FAIL" -Test "External Services Config Read" -Message $_.Exception.Message
    }
}

function Test-SystemMonitoringConfig {
    Write-Host "Testing System Monitoring Configuration..." -ForegroundColor Yellow
    
    try {
        $config = Get-Content "$ConfigDir/system-monitoring.json" | ConvertFrom-Json
        
        # Test collectors
        $collectors = @("prometheus", "grafana", "alertmanager", "jaeger", "elasticsearch")
        $enabledCollectors = 0
        foreach ($collector in $collectors) {
            if ($config.collectors.$collector.enabled) {
                $enabledCollectors++
            }
        }
        
        if ($enabledCollectors -ge 4) {
            Write-Host "  ✓ Comprehensive monitoring stack configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Monitoring Stack" -Message "$enabledCollectors collectors enabled"
        } else {
            Write-Host "  ⚠ Limited monitoring stack" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Monitoring Stack" -Message "Only $enabledCollectors collectors enabled"
        }
        
        # Test custom metrics
        $businessMetrics = $config.custom_metrics.business.Count
        $technicalMetrics = $config.custom_metrics.technical.Count
        
        if ($businessMetrics -gt 0 -and $technicalMetrics -gt 0) {
            Write-Host "  ✓ Custom metrics configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Custom Metrics" -Message "$businessMetrics business + $technicalMetrics technical metrics"
        } else {
            Write-Host "  ⚠ Limited custom metrics" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Custom Metrics" -Message "Few custom metrics configured"
        }
        
        # Test SLA targets
        if ($config.sla.targets.availability -ge 99.9) {
            Write-Host "  ✓ High availability SLA target set" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "SLA Targets" -Message "$($config.sla.targets.availability)% availability target"
        } else {
            Write-Host "  ⚠ Low availability SLA target" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "SLA Targets" -Message "$($config.sla.targets.availability)% availability target"
        }
        
    }
    catch {
        Write-Host "  ✗ Error reading system monitoring configuration: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult -Status "FAIL" -Test "System Monitoring Config Read" -Message $_.Exception.Message
    }
}

function Test-ProductionEnvironmentConfig {
    Write-Host "Testing Production Environment Configuration..." -ForegroundColor Yellow
    
    try {
        $config = Get-Content "$ConfigDir/production-environment.json" | ConvertFrom-Json
        
        # Test multi-region setup
        if ($config.deployment.multiRegion.enabled -and $config.deployment.multiRegion.regions.Count -ge 2) {
            Write-Host "  ✓ Multi-region deployment configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Multi-Region" -Message "$($config.deployment.multiRegion.regions.Count) regions configured"
        } else {
            Write-Host "  ⚠ Single region deployment" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Multi-Region" -Message "Multi-region not fully configured"
        }
        
        # Test autoscaling
        if ($config.infrastructure.autoscaling.enabled) {
            Write-Host "  ✓ Autoscaling configured" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Autoscaling" -Message "Min: $($config.infrastructure.autoscaling.minInstances), Max: $($config.infrastructure.autoscaling.maxInstances)"
        } else {
            Write-Host "  ✗ Autoscaling not configured" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "Autoscaling" -Message "Autoscaling not enabled"
        }
        
        # Test security features
        if ($config.security.encryption.atRest.enabled -and $config.security.encryption.inTransit.enabled) {
            Write-Host "  ✓ Encryption configured for data at rest and in transit" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Encryption" -Message "Full encryption enabled"
        } else {
            Write-Host "  ✗ Encryption not fully configured" -ForegroundColor Red
            Add-TestResult -Status "FAIL" -Test "Encryption" -Message "Missing encryption configuration"
        }
        
        # Test backup strategy
        if ($config.backup.database.crossRegion -and $config.backup.database.testing.automated) {
            Write-Host "  ✓ Comprehensive backup strategy" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Backup Strategy" -Message "Cross-region with automated testing"
        } else {
            Write-Host "  ⚠ Basic backup strategy" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Backup Strategy" -Message "Limited backup configuration"
        }
        
        # Test disaster recovery
        if ($config.disaster_recovery.rto -le 3600 -and $config.disaster_recovery.rpo -le 900) {
            Write-Host "  ✓ Disaster recovery targets met" -ForegroundColor Green
            Add-TestResult -Status "PASS" -Test "Disaster Recovery" -Message "RTO: $($config.disaster_recovery.rto)s, RPO: $($config.disaster_recovery.rpo)s"
        } else {
            Write-Host "  ⚠ Disaster recovery targets high" -ForegroundColor Yellow
            Add-TestResult -Status "WARN" -Test "Disaster Recovery" -Message "High RTO/RPO targets"
        }
        
    }
    catch {
        Write-Host "  ✗ Error reading production environment configuration: $($_.Exception.Message)" -ForegroundColor Red
        Add-TestResult -Status "FAIL" -Test "Production Environment Config Read" -Message $_.Exception.Message
    }
}

function Show-TestReport {
    Write-Host ""
    Write-Host "Integration Configuration Test Report" -ForegroundColor Blue
    Write-Host "====================================" -ForegroundColor Blue
    Write-Host ""
    
    $passCount = 0
    $failCount = 0
    $warnCount = 0
    
    Write-Host ("{0,-10} {1,-35} {2}" -f "STATUS", "TEST", "MESSAGE")
    Write-Host ("{0,-10} {1,-35} {2}" -f "------", "----", "-------")
    
    foreach ($result in $TestResults) {
        switch ($result.Status) {
            "PASS" {
                Write-Host ("{0,-10} {1,-35} {2}" -f "PASS", $result.Test, $result.Message) -ForegroundColor Green
                $passCount++
            }
            "FAIL" {
                Write-Host ("{0,-10} {1,-35} {2}" -f "FAIL", $result.Test, $result.Message) -ForegroundColor Red
                $failCount++
            }
            "WARN" {
                Write-Host ("{0,-10} {1,-35} {2}" -f "WARN", $result.Test, $result.Message) -ForegroundColor Yellow
                $warnCount++
            }
        }
    }
    
    Write-Host ""
    Write-Host "Test Summary:" -ForegroundColor Blue
    Write-Host "  Passed: $passCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor Red
    Write-Host "  Warnings: $warnCount" -ForegroundColor Yellow
    Write-Host ""
    
    $totalTests = $passCount + $failCount + $warnCount
    $successRate = [math]::Round(($passCount / $totalTests) * 100, 1)
    
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })
    
    if ($failCount -eq 0) {
        Write-Host ""
        Write-Host "✓ All critical tests passed! Configuration is production-ready." -ForegroundColor Green
        if ($warnCount -gt 0) {
            Write-Host "⚠ Please review warnings for optimization opportunities." -ForegroundColor Yellow
        }
        return $true
    } else {
        Write-Host ""
        Write-Host "✗ Some critical tests failed. Please address the issues before production deployment." -ForegroundColor Red
        return $false
    }
}

# Main execution
function Main {
    Write-Host "Starting integration configuration tests..." -ForegroundColor Yellow
    Write-Host ""
    
    Test-AtomiqBridgeConfig
    Write-Host ""
    
    Test-DefiProtocolsConfig
    Write-Host ""
    
    Test-ApiSecurityConfig
    Write-Host ""
    
    Test-MonitoringConfig
    Write-Host ""
    
    Test-ExternalServicesConfig
    Write-Host ""
    
    Test-SystemMonitoringConfig
    Write-Host ""
    
    Test-ProductionEnvironmentConfig
    
    $success = Show-TestReport
    
    if ($success) {
        exit 0
    } else {
        exit 1
    }
}

# Run main function
Main