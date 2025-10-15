#!/bin/bash

# BitFlow Security Test Runner
# Comprehensive security testing script for the BitFlow protocol

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPORT_DIR="./security_reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORT_DIR/security_report_$TIMESTAMP.json"

# Create report directory
mkdir -p "$REPORT_DIR"

echo -e "${BLUE}🔒 BitFlow Security Test Suite${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Function to print section headers
print_section() {
    echo -e "${BLUE}📋 $1${NC}"
    echo "----------------------------------------"
}

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

# Function to run Cairo tests
run_cairo_tests() {
    local test_file=$1
    local test_name=$2
    
    echo "Running $test_name..."
    if scarb test --package bitflow --filter "$test_file" > /dev/null 2>&1; then
        print_result 0 "$test_name passed"
        return 0
    else
        print_result 1 "$test_name failed"
        return 1
    fi
}

# Initialize test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Start security testing
echo -e "${YELLOW}Starting comprehensive security testing...${NC}"
echo ""

# 1. Smart Contract Security Tests
print_section "Smart Contract Security Tests"

# Reentrancy protection tests
run_cairo_tests "smart_contract_security_tests::test_reentrancy_protection" "Reentrancy Protection"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Access control tests
run_cairo_tests "smart_contract_security_tests::test_access_control_enforcement" "Access Control Enforcement"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Integer overflow protection
run_cairo_tests "smart_contract_security_tests::test_integer_overflow_protection" "Integer Overflow Protection"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Front-running protection
run_cairo_tests "smart_contract_security_tests::test_front_running_protection" "Front-running Protection"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Flash loan attack resistance
run_cairo_tests "smart_contract_security_tests::test_flash_loan_attack_resistance" "Flash Loan Attack Resistance"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# DoS resistance
run_cairo_tests "smart_contract_security_tests::test_denial_of_service_resistance" "DoS Resistance"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Signature replay protection
run_cairo_tests "smart_contract_security_tests::test_signature_replay_protection" "Signature Replay Protection"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Cross-function reentrancy
run_cairo_tests "smart_contract_security_tests::test_cross_function_reentrancy" "Cross-function Reentrancy"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# State manipulation attacks
run_cairo_tests "smart_contract_security_tests::test_state_manipulation_attacks" "State Manipulation Attacks"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

echo ""

# 2. Access Control Tests
print_section "Access Control & Permission Tests"

# Admin role management
run_cairo_tests "access_control_tests::test_admin_role_management" "Admin Role Management"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Stream ownership validation
run_cairo_tests "access_control_tests::test_stream_ownership_validation" "Stream Ownership Validation"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Subscription access control
run_cairo_tests "access_control_tests::test_subscription_access_control" "Subscription Access Control"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Emergency functions access
run_cairo_tests "access_control_tests::test_emergency_functions_access" "Emergency Functions Access"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Bridge access control
run_cairo_tests "access_control_tests::test_bridge_access_control" "Bridge Access Control"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Yield management access
run_cairo_tests "access_control_tests::test_yield_management_access" "Yield Management Access"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Multi-signature requirements
run_cairo_tests "access_control_tests::test_multi_signature_requirements" "Multi-signature Requirements"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Role-based permissions
run_cairo_tests "access_control_tests::test_role_based_permissions" "Role-based Permissions"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Time-locked operations
run_cairo_tests "access_control_tests::test_time_locked_operations" "Time-locked Operations"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

echo ""

# 3. Vulnerability Scanner Tests
print_section "Automated Vulnerability Scanning"

# Comprehensive vulnerability scan
run_cairo_tests "vulnerability_scanner_tests::test_comprehensive_vulnerability_scan" "Comprehensive Vulnerability Scan"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Gas vulnerability detection
run_cairo_tests "vulnerability_scanner_tests::test_gas_vulnerability_detection" "Gas Vulnerability Detection"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# State manipulation detection
run_cairo_tests "vulnerability_scanner_tests::test_state_manipulation_detection" "State Manipulation Detection"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Risk assessment calculation
run_cairo_tests "vulnerability_scanner_tests::test_risk_assessment_calculation" "Risk Assessment Calculation"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

# Compliance checking
run_cairo_tests "vulnerability_scanner_tests::test_compliance_checking" "Compliance Checking"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [ $? -eq 0 ]; then PASSED_TESTS=$((PASSED_TESTS + 1)); else FAILED_TESTS=$((FAILED_TESTS + 1)); fi

echo ""

# 4. API Security Tests (if Node.js API is available)
print_section "API Security Tests"

if command -v npm &> /dev/null && [ -f "api/package.json" ]; then
    echo "Running API security tests..."
    
    cd api
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "Installing API dependencies..."
        npm install > /dev/null 2>&1
    fi
    
    # Run API security tests
    if npm test -- --grep "security" > /dev/null 2>&1; then
        print_result 0 "API Security Tests"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        print_result 1 "API Security Tests"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    cd ..
else
    echo -e "${YELLOW}⚠️  API security tests skipped (Node.js/npm not available or API not found)${NC}"
fi

echo ""

# 5. Generate Security Report
print_section "Generating Security Report"

# Create JSON report
cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "summary": {
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "success_rate": $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)
  },
  "test_categories": {
    "smart_contract_security": {
      "tests_run": 9,
      "description": "Core smart contract security vulnerabilities"
    },
    "access_control": {
      "tests_run": 9,
      "description": "Access control and permission validation"
    },
    "vulnerability_scanning": {
      "tests_run": 5,
      "description": "Automated vulnerability detection"
    },
    "api_security": {
      "tests_run": 1,
      "description": "API endpoint security testing"
    }
  },
  "security_status": "$(if [ $FAILED_TESTS -eq 0 ]; then echo "SECURE"; else echo "VULNERABILITIES_DETECTED"; fi)",
  "recommendations": [
    "Continue regular security audits",
    "Monitor for new attack vectors",
    "Keep dependencies updated",
    "Maintain bug bounty program"
  ]
}
EOF

echo -e "${GREEN}✅ Security report generated: $REPORT_FILE${NC}"

# 6. Summary
echo ""
print_section "Security Test Summary"

echo "Total Tests Run: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 All security tests passed!${NC}"
    echo -e "${GREEN}✅ BitFlow protocol security status: SECURE${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some security tests failed!${NC}"
    echo -e "${RED}❌ BitFlow protocol security status: VULNERABILITIES DETECTED${NC}"
    echo ""
    echo -e "${YELLOW}Please review failed tests and address security issues before deployment.${NC}"
    exit 1
fi