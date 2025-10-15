# BitFlow Production Setup Validation Script (PowerShell)
# This script validates that all external service integrations are properly configured

param(
    [string]$Environment = "production",
    [string]$ConfigDir = "config"
)

$ValidationResults = @()

Write-Host "BitFlow Production Setup Validation" -ForegroundColor Blue
Write-Host "====================================" -ForegroundColor Blue
Write-Host ""

# Function to add validation result
function Add-ValidationResult {
    param(
        [string]$Status,
        [string]$Component,
        [string]$Message
    )
    
    $script:ValidationResults += [PSCustomObject]@{
        Status = $Status
        Component = $Component
        Message = $Message
    }
}

# Function to test HTTP endpoint
function Test-HttpEndpoint {
    param(
        [string]$Name,
        [string]$Url,
        [int]$ExpectedStatus = 200,
        [int]$Timeout = 10,
        [hashtable]$Headers = @{}
    )
    
    Write-Host -NoNewline "Testing $Name... "
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers -TimeoutSec $Timeout -UseBasicParsing
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Host "Pass" -ForegroundColor Green
            Add-ValidationResult -Status "PASS" -Component $Name -Message "HTTP $($response.StatusCode)"
            return $true
        } else {
            Write-Host "Fail (HTTP $($response.StatusCode))" -ForegroundColor Red
            Add-ValidationResult -Status "FAIL" -Component $Name -Message "Expected HTTP $ExpectedStatus, got $($response.StatusCode)"
            return $false
        }
    }
    catch {
        Write-Host "Fail (Connection failed)" -ForegroundColor Red
        Add-ValidationResult -Status "FAIL" -Component $Name -Message "Connection failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to validate configuration files
function Test-ConfigurationFiles {
    Write-Host "Validating configuration files..." -ForegroundColor Yellow
    
    $configs = @(
        "atomiq-bridge.json",
        "defi-protocols.json",
        "api-security.json",
        "monitoring-alerts.json",
        "external-services.json",
        "system-monitoring.json",
        "production-environment.json"
    )
    
    foreach ($config in $configs) {
        Write-Host -NoNewline "Checking $config... "
        $configPath = Join-Path $ConfigDir $config
        
        if (Test-Path $configPath) {
            try {
                Get-Content $configPath | ConvertFrom-Json | Out-Null
                Write-Host "Pass" -ForegroundColor Green
                Add-ValidationResult -Status "PASS" -Component "Config: $config" -Message "Valid JSON"
            }
            catch {
                Write-Host "Fail (Invalid JSON)" -ForegroundColor Red
                Add-ValidationResult -Status "FAIL" -Component "Config: $config" -Message "Invalid JSON format"
            }
        } else {
            Write-Host "Fail (Missing)" -ForegroundColor Red
            Add-ValidationResult -Status "FAIL" -Component "Config: $config" -Message "File not found"
        }
    }
}

# Function to validate environment variables
function Test-EnvironmentVariables {
    Write-Host "Validating environment variables..." -ForegroundColor Yellow
    
    $requiredVars = @(
        "STARKNET_RPC_URL",
        "DATABASE_URL",
        "REDIS_URL",
        "JWT_SECRET",
        "WEBHOOK_SECRET"
    )
    
    foreach ($var in $requiredVars) {
        Write-Host -NoNewline "Checking $var... "
        $value = [Environment]::GetEnvironmentVariable($var)
        
        if ($value) {
            Write-Host "Pass" -ForegroundColor Green
            Add-ValidationResult -Status "PASS" -Component "EnvVar: $var" -Message "Set"
        } else {
            Write-Host "Fail" -ForegroundColor Red
            Add-ValidationResult -Status "FAIL" -Component "EnvVar: $var" -Message "Not set"
        }
    }
}

# Function to test external services
function Test-ExternalServices {
    Write-Host "Testing external service connectivity..." -ForegroundColor Yellow
    
    # Test DeFi protocols
    $defiConfigPath = Join-Path $ConfigDir "defi-protocols.json"
    if (Test-Path $defiConfigPath) {
        try {
            $defiConfig = Get-Content $defiConfigPath | ConvertFrom-Json
            
            $vesuUrl = $defiConfig.vesu.$Environment.apiUrl
            $trovesUrl = $defiConfig.troves.$Environment.apiUrl
            $endurfiUrl = $defiConfig.endurfi.$Environment.apiUrl
            
            if ($vesuUrl) {
                Test-HttpEndpoint -Name "Vesu Protocol" -Url "$vesuUrl/v1/health" -Timeout 15
            }
            
            if ($trovesUrl) {
                Test-HttpEndpoint -Name "Troves Protocol" -Url "$trovesUrl/v1/health" -Timeout 15
            }
            
            if ($endurfiUrl) {
                Test-HttpEndpoint -Name "Endur.fi Protocol" -Url "$endurfiUrl/v1/health" -Timeout 15
            }
        }
        catch {
            Write-Host "Error reading DeFi config: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Function to test API endpoints
function Test-ApiEndpoints {
    Write-Host "Testing API endpoints..." -ForegroundColor Yellow
    
    Test-HttpEndpoint -Name "API Health" -Url "http://localhost:3000/health" -Timeout 10
    Test-HttpEndpoint -Name "API Metrics" -Url "http://localhost:3000/metrics" -Timeout 10
}

# Function to generate validation report
function Show-ValidationReport {
    Write-Host ""
    Write-Host "Validation Report" -ForegroundColor Blue
    Write-Host "=================" -ForegroundColor Blue
    Write-Host ""
    
    $passCount = 0
    $failCount = 0
    $warnCount = 0
    
    Write-Host ("{0,-20} {1,-30} {2}" -f "STATUS", "COMPONENT", "MESSAGE")
    Write-Host ("{0,-20} {1,-30} {2}" -f "------", "---------", "-------")
    
    foreach ($result in $ValidationResults) {
        switch ($result.Status) {
            "PASS" {
                Write-Host ("{0,-20} {1,-30} {2}" -f "Pass", $result.Component, $result.Message) -ForegroundColor Green
                $passCount++
            }
            "FAIL" {
                Write-Host ("{0,-20} {1,-30} {2}" -f "Fail", $result.Component, $result.Message) -ForegroundColor Red
                $failCount++
            }
            "WARN" {
                Write-Host ("{0,-20} {1,-30} {2}" -f "Warn", $result.Component, $result.Message) -ForegroundColor Yellow
                $warnCount++
            }
        }
    }
    
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Blue
    Write-Host "  Passed: $passCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor Red
    Write-Host "  Warnings: $warnCount" -ForegroundColor Yellow
    Write-Host ""
    
    if ($failCount -eq 0) {
        Write-Host "Production setup validation completed successfully!" -ForegroundColor Green
        if ($warnCount -gt 0) {
            Write-Host "Please review the warnings above" -ForegroundColor Yellow
        }
        return $true
    } else {
        Write-Host "Production setup validation failed!" -ForegroundColor Red
        Write-Host "Please fix the failed components before deploying to production" -ForegroundColor Red
        return $false
    }
}

# Main execution
function Main {
    Write-Host "Starting validation for $Environment environment..." -ForegroundColor Yellow
    Write-Host ""
    
    Test-ConfigurationFiles
    Write-Host ""
    
    Test-EnvironmentVariables
    Write-Host ""
    
    Test-ExternalServices
    Write-Host ""
    
    Test-ApiEndpoints
    
    $success = Show-ValidationReport
    
    if ($success) {
        exit 0
    } else {
        exit 1
    }
}

# Run main function
Main