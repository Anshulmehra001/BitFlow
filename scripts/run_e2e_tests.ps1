# BitFlow End-to-End Testing Script (PowerShell)
# This script runs the complete E2E testing suite for the BitFlow protocol

param(
    [string]$Network = "testnet",
    [int]$ParallelJobs = 4,
    [int]$Timeout = 3600,
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: .\run_e2e_tests.ps1 [OPTIONS]"
    Write-Host "Options:"
    Write-Host "  -Network NETWORK      Test network to use (default: testnet)"
    Write-Host "  -ParallelJobs JOBS    Number of parallel jobs (default: 4)"
    Write-Host "  -Timeout SECONDS      Test timeout in seconds (default: 3600)"
    Write-Host "  -Help                 Show this help message"
    exit 0
}

# Configuration
$TestNetwork = $Network
$ReportDir = "test-reports"
$CoverageDir = "coverage"

# Create directories
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
New-Item -ItemType Directory -Force -Path $CoverageDir | Out-Null

# Logging functions
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Blue
}

function Write-Error-Log {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning-Log {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

# Check prerequisites
function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check if Scarb is installed
    if (-not (Get-Command scarb -ErrorAction SilentlyContinue)) {
        Write-Error-Log "Scarb is not installed. Please install Scarb first."
        exit 1
    }
    
    # Check if Starknet Foundry is installed
    if (-not (Get-Command snforge -ErrorAction SilentlyContinue)) {
        Write-Error-Log "Starknet Foundry (snforge) is not installed. Please install it first."
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
}

# Setup test environment
function Initialize-TestEnvironment {
    Write-Log "Setting up test environment..."
    
    # Build the project
    Write-Log "Building BitFlow contracts..."
    $buildResult = & scarb build
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Log "Failed to build contracts"
        exit 1
    }
    
    # Setup test network configuration
    $env:STARKNET_NETWORK = $TestNetwork
    $env:STARKNET_RPC_URL = "http://localhost:5050"
    
    Write-Success "Test environment setup complete"
}

# Run unit tests first
function Invoke-UnitTests {
    Write-Log "Running unit tests..."
    
    $logFile = Join-Path $ReportDir "unit_tests.log"
    $coverageDir = Join-Path $CoverageDir "unit"
    
    & snforge test --coverage --coverage-dir $coverageDir 2>&1 | Tee-Object -FilePath $logFile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Log "Unit tests failed"
        return $false
    }
    
    Write-Success "Unit tests passed"
    return $true
}

# Run user journey tests
function Invoke-UserJourneyTests {
    Write-Log "Running user journey tests..."
    
    $logFile = Join-Path $ReportDir "user_journey_tests.log"
    $coverageDir = Join-Path $CoverageDir "user_journey"
    
    & snforge test tests::e2e::user_journey_tests --coverage --coverage-dir $coverageDir 2>&1 | Tee-Object -FilePath $logFile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Log "User journey tests failed"
        return $false
    }
    
    Write-Success "User journey tests passed"
    return $true
}

# Run cross-chain flow tests
function Invoke-CrossChainTests {
    Write-Log "Running cross-chain flow tests..."
    
    $logFile = Join-Path $ReportDir "cross_chain_tests.log"
    $coverageDir = Join-Path $CoverageDir "cross_chain"
    
    & snforge test tests::e2e::cross_chain_flow_tests --coverage --coverage-dir $coverageDir 2>&1 | Tee-Object -FilePath $logFile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Log "Cross-chain flow tests failed"
        return $false
    }
    
    Write-Success "Cross-chain flow tests passed"
    return $true
}

# Run performance tests
function Invoke-PerformanceTests {
    Write-Log "Running performance tests..."
    
    $logFile = Join-Path $ReportDir "performance_tests.log"
    $coverageDir = Join-Path $CoverageDir "performance"
    
    & snforge test tests::e2e::performance_tests --coverage --coverage-dir $coverageDir 2>&1 | Tee-Object -FilePath $logFile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Log "Performance tests failed"
        return $false
    }
    
    Write-Success "Performance tests passed"
    return $true
}

# Run load tests
function Invoke-LoadTests {
    Write-Log "Running load tests..."
    
    $logFile = Join-Path $ReportDir "load_tests.log"
    $coverageDir = Join-Path $CoverageDir "load"
    
    & snforge test tests::e2e::load_tests --coverage --coverage-dir $coverageDir 2>&1 | Tee-Object -FilePath $logFile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Log "Load tests failed"
        return $false
    }
    
    Write-Success "Load tests passed"
    return $true
}

# Generate comprehensive test report
function New-TestReport {
    Write-Log "Generating comprehensive test report..."
    
    $reportFile = Join-Path $ReportDir "test_summary.html"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>BitFlow E2E Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .suite { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .passed { background-color: #d4edda; }
        .failed { background-color: #f8d7da; }
        .metrics { display: flex; justify-content: space-around; margin: 20px 0; }
        .metric { text-align: center; padding: 10px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>BitFlow Protocol - End-to-End Test Report</h1>
        <p>Generated on: $timestamp</p>
        <p>Test Network: $TestNetwork</p>
    </div>
    
    <div class="metrics">
        <div class="metric">
            <h3>Total Tests</h3>
            <p id="total-tests">-</p>
        </div>
        <div class="metric">
            <h3>Passed</h3>
            <p id="passed-tests">-</p>
        </div>
        <div class="metric">
            <h3>Failed</h3>
            <p id="failed-tests">-</p>
        </div>
        <div class="metric">
            <h3>Success Rate</h3>
            <p id="success-rate">-</p>
        </div>
    </div>
    
    <div class="suite">
        <h2>Test Suites</h2>
        <ul>
            <li>Unit Tests: <span class="status" id="unit-status">-</span></li>
            <li>User Journey Tests: <span class="status" id="journey-status">-</span></li>
            <li>Cross-Chain Tests: <span class="status" id="crosschain-status">-</span></li>
            <li>Performance Tests: <span class="status" id="performance-status">-</span></li>
            <li>Load Tests: <span class="status" id="load-status">-</span></li>
        </ul>
    </div>
    
    <div class="suite">
        <h2>Coverage Report</h2>
        <p>Detailed coverage reports are available in the coverage directory.</p>
    </div>
</body>
</html>
"@
    
    $htmlContent | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Success "Test report generated at $reportFile"
}

# Cleanup function
function Clear-TestEnvironment {
    Write-Log "Cleaning up test environment..."
    # Add any cleanup tasks here
    Write-Success "Cleanup complete"
}

# Main execution
function Main {
    $startTime = Get-Date
    $failedSuites = @()
    
    try {
        # Setup
        Test-Prerequisites
        Initialize-TestEnvironment
        
        # Run test suites
        Write-Log "Starting test execution..."
        
        if (-not (Invoke-UnitTests)) {
            $failedSuites += "unit"
        }
        
        if (-not (Invoke-UserJourneyTests)) {
            $failedSuites += "user_journey"
        }
        
        if (-not (Invoke-CrossChainTests)) {
            $failedSuites += "cross_chain"
        }
        
        if (-not (Invoke-PerformanceTests)) {
            $failedSuites += "performance"
        }
        
        if (-not (Invoke-LoadTests)) {
            $failedSuites += "load"
        }
        
        # Generate report
        New-TestReport
        
        # Calculate execution time
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        # Summary
        Write-Host ""
        Write-Host "======================================"
        Write-Log "E2E Testing Suite Complete"
        Write-Log "Total execution time: $([math]::Round($duration, 2))s"
        
        if ($failedSuites.Count -eq 0) {
            Write-Success "All test suites passed! ✅"
            Write-Host ""
            Write-Success "🚀 BitFlow is ready for deployment!"
            exit 0
        } else {
            Write-Error-Log "Failed test suites: $($failedSuites -join ', ')"
            Write-Host ""
            Write-Error-Log "❌ BitFlow is not ready for deployment"
            exit 1
        }
    }
    finally {
        Clear-TestEnvironment
    }
}

# Run main function
Main