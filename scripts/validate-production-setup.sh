#!/bin/bash

# BitFlow Production Setup Validation Script
# This script validates that all external service integrations are properly configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ENVIRONMENT=${ENVIRONMENT:-"production"}
CONFIG_DIR="config"
VALIDATION_RESULTS=()

echo -e "${BLUE}BitFlow Production Setup Validation${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Function to add validation result
add_result() {
    local status=$1
    local component=$2
    local message=$3
    VALIDATION_RESULTS+=("$status|$component|$message")
}

# Function to test HTTP endpoint
test_http_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    local timeout=${4:-10}
    local headers=$5
    
    echo -n "Testing $name... "
    
    local cmd="curl -s -o /dev/null -w '%{http_code}' --max-time $timeout"
    if [ -n "$headers" ]; then
        cmd="$cmd $headers"
    fi
    cmd="$cmd '$url'"
    
    local status_code=$(eval $cmd 2>/dev/null || echo "000")
    
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✓${NC}"
        add_result "PASS" "$name" "HTTP $status_code"
        return 0
    else
        echo -e "${RED}✗ (HTTP $status_code)${NC}"
        add_result "FAIL" "$name" "Expected HTTP $expected_status, got $status_code"
        return 1
    fi
}

# Function to test database connection
test_database() {
    echo -n "Testing database connection... "
    
    if command -v pg_isready &> /dev/null; then
        if pg_isready -h localhost -p 5432 -U bitflow &> /dev/null; then
            echo -e "${GREEN}✓${NC}"
            add_result "PASS" "Database" "PostgreSQL connection successful"
        else
            echo -e "${RED}✗${NC}"
            add_result "FAIL" "Database" "PostgreSQL connection failed"
        fi
    else
        echo -e "${YELLOW}⚠ (pg_isready not available)${NC}"
        add_result "WARN" "Database" "Cannot test - pg_isready not available"
    fi
}

# Function to test Redis connection
test_redis() {
    echo -n "Testing Redis connection... "
    
    if command -v redis-cli &> /dev/null; then
        if redis-cli ping &> /dev/null; then
            echo -e "${GREEN}✓${NC}"
            add_result "PASS" "Redis" "Connection successful"
        else
            echo -e "${RED}✗${NC}"
            add_result "FAIL" "Redis" "Connection failed"
        fi
    else
        echo -e "${YELLOW}⚠ (redis-cli not available)${NC}"
        add_result "WARN" "Redis" "Cannot test - redis-cli not available"
    fi
}

# Function to validate configuration files
validate_configs() {
    echo -e "${YELLOW}Validating configuration files...${NC}"
    
    local configs=(
        "atomiq-bridge.json"
        "defi-protocols.json"
        "api-security.json"
        "monitoring-alerts.json"
        "external-services.json"
        "system-monitoring.json"
        "production-environment.json"
    )
    
    for config in "${configs[@]}"; do
        echo -n "Checking $config... "
        if [ -f "$CONFIG_DIR/$config" ]; then
            if jq empty "$CONFIG_DIR/$config" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                add_result "PASS" "Config: $config" "Valid JSON"
            else
                echo -e "${RED}✗ (Invalid JSON)${NC}"
                add_result "FAIL" "Config: $config" "Invalid JSON format"
            fi
        else
            echo -e "${RED}✗ (Missing)${NC}"
            add_result "FAIL" "Config: $config" "File not found"
        fi
    done
}

# Function to validate environment variables
validate_environment() {
    echo -e "${YELLOW}Validating environment variables...${NC}"
    
    local required_vars=(
        "STARKNET_RPC_URL"
        "DATABASE_URL"
        "REDIS_URL"
        "ATOMIQ_BRIDGE_API_KEY"
        "SLACK_WEBHOOK_URL"
        "SMTP_HOST"
        "SMTP_USER"
        "SMTP_PASSWORD"
        "JWT_SECRET"
        "WEBHOOK_SECRET"
    )
    
    for var in "${required_vars[@]}"; do
        echo -n "Checking $var... "
        if [ -n "${!var}" ]; then
            echo -e "${GREEN}✓${NC}"
            add_result "PASS" "EnvVar: $var" "Set"
        else
            echo -e "${RED}✗${NC}"
            add_result "FAIL" "EnvVar: $var" "Not set"
        fi
    done
}

# Function to test external services
test_external_services() {
    echo -e "${YELLOW}Testing external service connectivity...${NC}"
    
    # Test Starknet RPC
    if [ -n "$STARKNET_RPC_URL" ]; then
        test_http_endpoint "Starknet RPC" "$STARKNET_RPC_URL" 200 30 "-H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"starknet_blockNumber\",\"params\":[],\"id\":1}'"
    fi
    
    # Test Atomiq Bridge
    if [ -n "$ATOMIQ_BRIDGE_API_URL" ] && [ -n "$ATOMIQ_BRIDGE_API_KEY" ]; then
        test_http_endpoint "Atomiq Bridge" "$ATOMIQ_BRIDGE_API_URL/v1/health" 200 15 "-H 'Authorization: Bearer $ATOMIQ_BRIDGE_API_KEY'"
    fi
    
    # Test DeFi protocols
    local defi_config="$CONFIG_DIR/defi-protocols.json"
    if [ -f "$defi_config" ]; then
        local vesu_url=$(jq -r ".vesu.$ENVIRONMENT.apiUrl" "$defi_config")
        local troves_url=$(jq -r ".troves.$ENVIRONMENT.apiUrl" "$defi_config")
        local endurfi_url=$(jq -r ".endurfi.$ENVIRONMENT.apiUrl" "$defi_config")
        
        if [ "$vesu_url" != "null" ]; then
            test_http_endpoint "Vesu Protocol" "$vesu_url/v1/health" 200 15
        fi
        
        if [ "$troves_url" != "null" ]; then
            test_http_endpoint "Troves Protocol" "$troves_url/v1/health" 200 15
        fi
        
        if [ "$endurfi_url" != "null" ]; then
            test_http_endpoint "Endur.fi Protocol" "$endurfi_url/v1/health" 200 15
        fi
    fi
}

# Function to test monitoring services
test_monitoring() {
    echo -e "${YELLOW}Testing monitoring services...${NC}"
    
    # Test Prometheus
    test_http_endpoint "Prometheus" "http://localhost:9090/-/healthy" 200 10
    
    # Test Grafana
    test_http_endpoint "Grafana" "http://localhost:3001/api/health" 200 10
    
    # Test Alertmanager
    test_http_endpoint "Alertmanager" "http://localhost:9093/-/healthy" 200 10
    
    # Test Elasticsearch
    test_http_endpoint "Elasticsearch" "http://localhost:9200/_cluster/health" 200 10
    
    # Test Jaeger
    test_http_endpoint "Jaeger" "http://localhost:16686/" 200 10
}

# Function to test notification channels
test_notifications() {
    echo -e "${YELLOW}Testing notification channels...${NC}"
    
    # Test Slack webhook
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        echo -n "Testing Slack webhook... "
        local payload='{"text":"BitFlow production validation test","channel":"#bitflow-alerts","username":"BitFlow Monitor"}'
        if curl -f -X POST -H "Content-Type: application/json" -d "$payload" "$SLACK_WEBHOOK_URL" &> /dev/null; then
            echo -e "${GREEN}✓${NC}"
            add_result "PASS" "Slack Webhook" "Message sent successfully"
        else
            echo -e "${RED}✗${NC}"
            add_result "FAIL" "Slack Webhook" "Failed to send message"
        fi
    fi
    
    # Test email configuration
    echo -n "Testing email configuration... "
    if command -v sendmail &> /dev/null && [ -n "$SMTP_HOST" ]; then
        echo "BitFlow production validation test" | mail -s "BitFlow Validation Test" "$SMTP_USER" 2>/dev/null && {
            echo -e "${GREEN}✓${NC}"
            add_result "PASS" "Email" "Test email sent"
        } || {
            echo -e "${RED}✗${NC}"
            add_result "FAIL" "Email" "Failed to send test email"
        }
    else
        echo -e "${YELLOW}⚠ (sendmail not available or SMTP not configured)${NC}"
        add_result "WARN" "Email" "Cannot test - sendmail not available or SMTP not configured"
    fi
}

# Function to validate security settings
validate_security() {
    echo -e "${YELLOW}Validating security settings...${NC}"
    
    # Check SSL/TLS certificates
    echo -n "Checking SSL certificates... "
    if command -v openssl &> /dev/null; then
        if openssl s_client -connect bitflow.app:443 -servername bitflow.app < /dev/null 2>/dev/null | openssl x509 -noout -dates &> /dev/null; then
            echo -e "${GREEN}✓${NC}"
            add_result "PASS" "SSL Certificate" "Valid certificate found"
        else
            echo -e "${YELLOW}⚠ (Cannot verify)${NC}"
            add_result "WARN" "SSL Certificate" "Cannot verify certificate"
        fi
    else
        echo -e "${YELLOW}⚠ (openssl not available)${NC}"
        add_result "WARN" "SSL Certificate" "Cannot test - openssl not available"
    fi
    
    # Check file permissions
    echo -n "Checking configuration file permissions... "
    local secure_files=(
        ".env.production"
        "config/api-security.json"
        "config/external-services.json"
    )
    
    local permission_issues=0
    for file in "${secure_files[@]}"; do
        if [ -f "$file" ]; then
            local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
            if [ "$perms" -gt 600 ]; then
                permission_issues=$((permission_issues + 1))
            fi
        fi
    done
    
    if [ $permission_issues -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
        add_result "PASS" "File Permissions" "Secure permissions set"
    else
        echo -e "${YELLOW}⚠ ($permission_issues files with loose permissions)${NC}"
        add_result "WARN" "File Permissions" "$permission_issues files with potentially insecure permissions"
    fi
}

# Function to test API endpoints
test_api() {
    echo -e "${YELLOW}Testing API endpoints...${NC}"
    
    # Test health endpoint
    test_http_endpoint "API Health" "http://localhost:3000/health" 200 10
    
    # Test metrics endpoint
    test_http_endpoint "API Metrics" "http://localhost:3000/metrics" 200 10
    
    # Test rate limiting
    echo -n "Testing rate limiting... "
    local rate_limit_test=0
    for i in {1..10}; do
        if curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://localhost:3000/health" | grep -q "200"; then
            rate_limit_test=$((rate_limit_test + 1))
        fi
    done
    
    if [ $rate_limit_test -gt 0 ]; then
        echo -e "${GREEN}✓ ($rate_limit_test/10 requests succeeded)${NC}"
        add_result "PASS" "Rate Limiting" "$rate_limit_test/10 requests succeeded"
    else
        echo -e "${RED}✗ (All requests failed)${NC}"
        add_result "FAIL" "Rate Limiting" "All test requests failed"
    fi
}

# Function to generate validation report
generate_report() {
    echo ""
    echo -e "${BLUE}Validation Report${NC}"
    echo -e "${BLUE}=================${NC}"
    echo ""
    
    local pass_count=0
    local fail_count=0
    local warn_count=0
    
    printf "%-20s %-30s %s\n" "STATUS" "COMPONENT" "MESSAGE"
    printf "%-20s %-30s %s\n" "------" "---------" "-------"
    
    for result in "${VALIDATION_RESULTS[@]}"; do
        IFS='|' read -r status component message <<< "$result"
        
        case $status in
            "PASS")
                printf "${GREEN}%-20s${NC} %-30s %s\n" "✓ PASS" "$component" "$message"
                pass_count=$((pass_count + 1))
                ;;
            "FAIL")
                printf "${RED}%-20s${NC} %-30s %s\n" "✗ FAIL" "$component" "$message"
                fail_count=$((fail_count + 1))
                ;;
            "WARN")
                printf "${YELLOW}%-20s${NC} %-30s %s\n" "⚠ WARN" "$component" "$message"
                warn_count=$((warn_count + 1))
                ;;
        esac
    done
    
    echo ""
    echo -e "${BLUE}Summary:${NC}"
    echo -e "  ${GREEN}Passed: $pass_count${NC}"
    echo -e "  ${RED}Failed: $fail_count${NC}"
    echo -e "  ${YELLOW}Warnings: $warn_count${NC}"
    echo ""
    
    if [ $fail_count -eq 0 ]; then
        echo -e "${GREEN}✓ Production setup validation completed successfully!${NC}"
        if [ $warn_count -gt 0 ]; then
            echo -e "${YELLOW}⚠ Please review the warnings above${NC}"
        fi
        return 0
    else
        echo -e "${RED}✗ Production setup validation failed!${NC}"
        echo -e "${RED}Please fix the failed components before deploying to production${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${YELLOW}Starting validation for $ENVIRONMENT environment...${NC}"
    echo ""
    
    validate_configs
    echo ""
    
    validate_environment
    echo ""
    
    test_database
    test_redis
    echo ""
    
    test_external_services
    echo ""
    
    test_monitoring
    echo ""
    
    test_notifications
    echo ""
    
    validate_security
    echo ""
    
    test_api
    
    generate_report
}

# Run main function
main "$@"