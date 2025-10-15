# BitFlow Security Test Runner (PowerShell)
# Comprehensive security testing script for the BitFlow protocol

param(
    [string]$ReportDir = "./security_reports",
    [switch]$Verbose = $false
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

# Configuration
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ReportFile = "$ReportDir/security_report_$Timestamp.json"

# Create report directory
if (!(Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}

Write-Host "🔒 BitFlow Security Test Suite" -ForegroundColor $Blue
Write-Host "================================" -ForegroundColor $Blue
Write-Host ""

# Function to print section headers
function Write-Section {
    param([string]$Title)
    Write-Host "📋 $Title" -ForegroundColor $Blue
    Write-Host "----------------------------------------"
}

# Function to print test results
function Write-Result {
    param([bool]$Success, [string]$TestName)
    if ($Success) {
        Write-Host "✅ $TestName" -ForegroundColor $Green
    } else {
        Write-Host "❌ $TestName" -ForegroundColor $Red
    }
}

# Function to run Cairo tests
function Invoke-CairoTest {
    param([string]$TestFile, [string]$TestName)
    
    Write-Host "Running $TestName..." -ForegroundColor Gray
    
    try {
        $result = & scarb test --package bitflow --filter $TestFile 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Result -Success $true -TestName "$TestName passed"
            return $true
        } else {
            Write-Result -Success $false -TestName "$TestName failed"
            if ($Verbose) {
                Write-Host $result -ForegroundColor Red
            }
            return $false
        }
    } catch {
        Write-Result -Success $false -TestName "$TestName failed with exception"
        if ($Verbose) {
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
        return $false
    }
}

# Initialize test results
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0

# Start security testing
Write-Host "Starting comprehensive security testing..." -ForegroundColor $Yellow
Write-Host ""

# 1. Smart Contract Security Tests
Write-Section "Smart Contract Security Tests"

$tests = @(
    @{Filter = "smart_contract_security_tests::test_reentrancy_protection"; Name = "Reentrancy Protection"},
    @{Filter = "smart_contract_security_tests::test_access_control_enforcement"; Name = "Access Control Enforcement"},
    @{Filter = "smart_contract_security_tests::test_integer_overflow_protection"; Name = "Integer Overflow Protection"},
    @{Filter = "smart_contract_security_tests::test_front_running_protection"; Name = "Front-running Protection"},
    @{Filter = "smart_contract_security_tests::test_flash_loan_attack_resistance"; Name = "Flash Loan Attack Resistance"},
    @{Filter = "smart_contract_security_tests::test_denial_of_service_resistance"; Name = "DoS Resistance"},
    @{Filter = "smart_contract_security_tests::test_signature_replay_protection"; Name = "Signature Replay Protection"},
    @{Filter = "smart_contract_security_tests::test_cross_function_reentrancy"; Name = "Cross-function Reentrancy"},
    @{Filter = "smart_contract_security_tests::test_state_manipulation_attacks"; Name = "State Manipulation Attacks"}
)

foreach ($test in $tests) {
    $TotalTests++
    if (Invoke-CairoTest -TestFile $test.Filter -TestName $test.Name) {
        $PassedTests++
    } else {
        $FailedTests++
    }
}

Write-Host ""

# 2. Access Control Tests
Write-Section "Access Control & Permission Tests"

$accessControlTests = @(
    @{Filter = "access_control_tests::test_admin_role_management"; Name = "Admin Role Management"},
    @{Filter = "access_control_tests::test_stream_ownership_validation"; Name = "Stream Ownership Validation"},
    @{Filter = "access_control_tests::test_subscription_access_control"; Name = "Subscription Access Control"},
    @{Filter = "access_control_tests::test_emergency_functions_access"; Name = "Emergency Functions Access"},
    @{Filter = "access_control_tests::test_bridge_access_control"; Name = "Bridge Access Control"},
    @{Filter = "access_control_tests::test_yield_management_access"; Name = "Yield Management Access"},
    @{Filter = "access_control_tests::test_multi_signature_requirements"; Name = "Multi-signature Requirements"},
    @{Filter = "access_control_tests::test_role_based_permissions"; Name = "Role-based Permissions"},
    @{Filter = "access_control_tests::test_time_locked_operations"; Name = "Time-locked Operations"}
)

foreach ($test in $accessControlTests) {
    $TotalTests++
    if (Invoke-CairoTest -TestFile $test.Filter -TestName $test.Name) {
        $PassedTests++
    } else {
        $FailedTests++
    }
}

Write-Host ""

# 3. Vulnerability Scanner Tests
Write-Section "Automated Vulnerability Scanning"

$vulnScannerTests = @(
    @{Filter = "vulnerability_scanner_tests::test_comprehensive_vulnerability_scan"; Name = "Comprehensive Vulnerability Scan"},
    @{Filter = "vulnerability_scanner_tests::test_gas_vulnerability_detection"; Name = "Gas Vulnerability Detection"},
    @{Filter = "vulnerability_scanner_tests::test_state_manipulation_detection"; Name = "State Manipulation Detection"},
    @{Filter = "vulnerability_scanner_tests::test_risk_assessment_calculation"; Name = "Risk Assessment Calculation"},
    @{Filter = "vulnerability_scanner_tests::test_compliance_checking"; Name = "Compliance Checking"}
)

foreach ($test in $vulnScannerTests) {
    $TotalTests++
    if (Invoke-CairoTest -TestFile $test.Filter -TestName $test.Name) {
        $PassedTests++
    } else {
        $FailedTests++
    }
}

Write-Host ""

# 4. API Security Tests (if Node.js API is available)
Write-Section "API Security Tests"

if ((Get-Command npm -ErrorAction SilentlyContinue) -and (Test-Path "api/package.json")) {
    Write-Host "Running API security tests..." -ForegroundColor Gray
    
    Push-Location api
    
    # Install dependencies if needed
    if (!(Test-Path "node_modules")) {
        Write-Host "Installing API dependencies..." -ForegroundColor Gray
        & npm install | Out-Null
    }
    
    # Run API security tests
    try {
        $result = & npm test -- --grep "security" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Result -Success $true -TestName "API Security Tests"
            $PassedTests++
        } else {
            Write-Result -Success $false -TestName "API Security Tests"
            $FailedTests++
        }
    } catch {
        Write-Result -Success $false -TestName "API Security Tests"
        $FailedTests++
    }
    $TotalTests++
    
    Pop-Location
} else {
    Write-Host "⚠️  API security tests skipped (Node.js/npm not available or API not found)" -ForegroundColor $Yellow
}

Write-Host ""

# 5. Generate Security Report
Write-Section "Generating Security Report"

$successRate = if ($TotalTests -gt 0) { [math]::Round(($PassedTests * 100) / $TotalTests, 2) } else { 0 }
$securityStatus = if ($FailedTests -eq 0) { "SECURE" } else { "VULNERABILITIES_DETECTED" }

$report = @{
    timestamp = $Timestamp
    summary = @{
        total_tests = $TotalTests
        passed_tests = $PassedTests
        failed_tests = $FailedTests
        success_rate = $successRate
    }
    test_categories = @{
        smart_contract_security = @{
            tests_run = 9
            description = "Core smart contract security vulnerabilities"
        }
        access_control = @{
            tests_run = 9
            description = "Access control and permission validation"
        }
        vulnerability_scanning = @{
            tests_run = 5
            description = "Automated vulnerability detection"
        }
        api_security = @{
            tests_run = 1
            description = "API endpoint security testing"
        }
    }
    security_status = $securityStatus
    recommendations = @(
        "Continue regular security audits",
        "Monitor for new attack vectors",
        "Keep dependencies updated",
        "Maintain bug bounty program"
    )
}

$report | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportFile -Encoding UTF8

Write-Host "✅ Security report generated: $ReportFile" -ForegroundColor $Green

# 6. Summary
Write-Host ""
Write-Section "Security Test Summary"

Write-Host "Total Tests Run: $TotalTests"
Write-Host "Passed: $PassedTests" -ForegroundColor $Green
Write-Host "Failed: $FailedTests" -ForegroundColor $Red

if ($FailedTests -eq 0) {
    Write-Host "🎉 All security tests passed!" -ForegroundColor $Green
    Write-Host "✅ BitFlow protocol security status: SECURE" -ForegroundColor $Green
    exit 0
} else {
    Write-Host "⚠️  Some security tests failed!" -ForegroundColor $Red
    Write-Host "❌ BitFlow protocol security status: VULNERABILITIES DETECTED" -ForegroundColor $Red
    Write-Host ""
    Write-Host "Please review failed tests and address security issues before deployment." -ForegroundColor $Yellow
    exit 1
}