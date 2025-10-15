#!/bin/bash

# BitFlow End-to-End Testing Script
# This script runs the complete E2E testing suite for the BitFlow protocol

set -e

echo "🚀 Starting BitFlow E2E Testing Suite"
echo "======================================"

# Configuration
TEST_NETWORK="testnet"
PARALLEL_JOBS=4
TIMEOUT=3600  # 1 hour timeout
REPORT_DIR="test-reports"
COVERAGE_DIR="coverage"

# Create directories
mkdir -p $REPORT_DIR
mkdir -p $COVERAGE_DIR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Scarb is installed
    if ! command -v scarb &> /dev/null; then
        error "Scarb is not installed. Please install Scarb first."
        exit 1
    fi
    
    # Check if Starknet Foundry is installed
    if ! command -v snforge &> /dev/null; then
        error "Starknet Foundry (snforge) is not installed. Please install it first."
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Setup test environment
setup_test_environment() {
    log "Setting up test environment..."
    
    # Build the project
    log "Building BitFlow contracts..."
    scarb build
    
    if [ $? -ne 0 ]; then
        error "Failed to build contracts"
        exit 1
    fi
    
    # Setup test network configuration
    export STARKNET_NETWORK=$TEST_NETWORK
    export STARKNET_RPC_URL="http://localhost:5050"
    
    success "Test environment setup complete"
}

# Run unit tests first
run_unit_tests() {
    log "Running unit tests..."
    
    snforge test --coverage --coverage-dir $COVERAGE_DIR/unit 2>&1 | tee $REPORT_DIR/unit_tests.log
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "Unit tests failed"
        return 1
    fi
    
    success "Unit tests passed"
    return 0
}

# Run user journey tests
run_user_journey_tests() {
    log "Running user journey tests..."
    
    snforge test tests::e2e::user_journey_tests --coverage --coverage-dir $COVERAGE_DIR/user_journey 2>&1 | tee $REPORT_DIR/user_journey_tests.log
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "User journey tests failed"
        return 1
    fi
    
    success "User journey tests passed"
    return 0
}

# Run cross-chain flow tests
run_cross_chain_tests() {
    log "Running cross-chain flow tests..."
    
    snforge test tests::e2e::cross_chain_flow_tests --coverage --coverage-dir $COVERAGE_DIR/cross_chain 2>&1 | tee $REPORT_DIR/cross_chain_tests.log
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "Cross-chain flow tests failed"
        return 1
    fi
    
    success "Cross-chain flow tests passed"
    return 0
}

# Run performance tests
run_performance_tests() {
    log "Running performance tests..."
    
    snforge test tests::e2e::performance_tests --coverage --coverage-dir $COVERAGE_DIR/performance 2>&1 | tee $REPORT_DIR/performance_tests.log
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "Performance tests failed"
        return 1
    fi
    
    success "Performance tests passed"
    return 0
}

# Run load tests
run_load_tests() {
    log "Running load tests..."
    
    snforge test tests::e2e::load_tests --coverage --coverage-dir $COVERAGE_DIR/load 2>&1 | tee $REPORT_DIR/load_tests.log
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "Load tests failed"
        return 1
    fi
    
    success "Load tests passed"
    return 0
}

# Generate comprehensive test report
generate_test_report() {
    log "Generating comprehensive test report..."
    
    cat > $REPORT_DIR/test_summary.html << EOF
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
        <p>Generated on: $(date)</p>
        <p>Test Network: $TEST_NETWORK</p>
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
EOF
    
    success "Test report generated at $REPORT_DIR/test_summary.html"
}

# Cleanup function
cleanup() {
    log "Cleaning up test environment..."
    # Add any cleanup tasks here
    success "Cleanup complete"
}

# Main execution
main() {
    local start_time=$(date +%s)
    local failed_suites=()
    
    # Setup
    check_prerequisites
    setup_test_environment
    
    # Run test suites
    log "Starting test execution..."
    
    if ! run_unit_tests; then
        failed_suites+=("unit")
    fi
    
    if ! run_user_journey_tests; then
        failed_suites+=("user_journey")
    fi
    
    if ! run_cross_chain_tests; then
        failed_suites+=("cross_chain")
    fi
    
    if ! run_performance_tests; then
        failed_suites+=("performance")
    fi
    
    if ! run_load_tests; then
        failed_suites+=("load")
    fi
    
    # Generate report
    generate_test_report
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Summary
    echo ""
    echo "======================================"
    log "E2E Testing Suite Complete"
    log "Total execution time: ${duration}s"
    
    if [ ${#failed_suites[@]} -eq 0 ]; then
        success "All test suites passed! ✅"
        echo ""
        success "🚀 BitFlow is ready for deployment!"
        exit 0
    else
        error "Failed test suites: ${failed_suites[*]}"
        echo ""
        error "❌ BitFlow is not ready for deployment"
        exit 1
    fi
}

# Handle script interruption
trap cleanup EXIT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            TEST_NETWORK="$2"
            shift 2
            ;;
        --parallel)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --network NETWORK    Test network to use (default: testnet)"
            echo "  --parallel JOBS      Number of parallel jobs (default: 4)"
            echo "  --timeout SECONDS    Test timeout in seconds (default: 3600)"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main