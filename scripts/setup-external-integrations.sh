#!/bin/bash

# BitFlow External Service Integration Setup Script
# This script configures integrations with Atomiq Bridge, DeFi protocols, and monitoring services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ENVIRONMENT=${ENVIRONMENT:-"production"}
CONFIG_DIR="config"

echo -e "${GREEN}Setting up BitFlow external service integrations for $ENVIRONMENT...${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if required environment variables are set
    required_vars=(
        "ATOMIQ_BRIDGE_API_KEY"
        "VESU_PROTOCOL_ADDRESS"
        "TROVES_PROTOCOL_ADDRESS"
        "SLACK_WEBHOOK_URL"
        "SMTP_HOST"
        "SMTP_USER"
        "SMTP_PASSWORD"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo -e "${RED}Error: Required environment variable $var is not set${NC}"
            exit 1
        fi
    done
    
    # Check if config files exist
    required_configs=(
        "$CONFIG_DIR/atomiq-bridge.json"
        "$CONFIG_DIR/defi-protocols.json"
        "$CONFIG_DIR/api-security.json"
        "$CONFIG_DIR/monitoring-alerts.json"
        "$CONFIG_DIR/external-services.json"
        "$CONFIG_DIR/system-monitoring.json"
        "$CONFIG_DIR/production-environment.json"
    )
    
    for config in "${required_configs[@]}"; do
        if [ ! -f "$config" ]; then
            echo -e "${RED}Error: Configuration file $config not found${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}Prerequisites check passed${NC}"
}

# Setup Atomiq Bridge integration
setup_atomiq_bridge() {
    echo -e "${YELLOW}Setting up Atomiq Bridge integration...${NC}"
    
    # Test Atomiq Bridge API connectivity
    ATOMIQ_API_URL=$(jq -r ".${ENVIRONMENT}.apiUrl" $CONFIG_DIR/atomiq-bridge.json)
    
    echo "Testing Atomiq Bridge API connectivity..."
    if curl -f -H "Authorization: Bearer $ATOMIQ_BRIDGE_API_KEY" "$ATOMIQ_API_URL/v1/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Atomiq Bridge API is accessible${NC}"
    else
        echo -e "${RED}✗ Failed to connect to Atomiq Bridge API${NC}"
        echo "Please check your API key and network connectivity"
        exit 1
    fi
    
    # Register webhook endpoints
    echo "Registering webhook endpoints..."
    webhook_payload=$(cat << EOF
{
    "url": "${API_BASE_URL}/webhooks/atomiq/transaction-confirmed",
    "events": ["transaction.confirmed", "transaction.failed", "bridge.status_update"],
    "secret": "${ATOMIQ_WEBHOOK_SECRET}"
}
EOF
)
    
    if curl -f -X POST \
        -H "Authorization: Bearer $ATOMIQ_BRIDGE_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$webhook_payload" \
        "$ATOMIQ_API_URL/v1/webhooks" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Webhook endpoints registered${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to register webhooks (may already exist)${NC}"
    fi
    
    echo -e "${GREEN}Atomiq Bridge integration setup completed${NC}"
}

# Setup DeFi protocol integrations
setup_defi_protocols() {
    echo -e "${YELLOW}Setting up DeFi protocol integrations...${NC}"
    
    # Test Vesu protocol
    echo "Testing Vesu protocol connectivity..."
    VESU_API_URL=$(jq -r ".vesu.${ENVIRONMENT}.apiUrl" $CONFIG_DIR/defi-protocols.json)
    
    if curl -f "$VESU_API_URL/v1/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Vesu protocol is accessible${NC}"
    else
        echo -e "${YELLOW}⚠ Vesu protocol may not be available${NC}"
    fi
    
    # Test Troves protocol
    echo "Testing Troves protocol connectivity..."
    TROVES_API_URL=$(jq -r ".troves.${ENVIRONMENT}.apiUrl" $CONFIG_DIR/defi-protocols.json)
    
    if curl -f "$TROVES_API_URL/v1/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Troves protocol is accessible${NC}"
    else
        echo -e "${YELLOW}⚠ Troves protocol may not be available${NC}"
    fi
    
    # Test Endur.fi protocol
    echo "Testing Endur.fi protocol connectivity..."
    ENDURFI_API_URL=$(jq -r ".endurfi.${ENVIRONMENT}.apiUrl" $CONFIG_DIR/defi-protocols.json)
    
    if curl -f "$ENDURFI_API_URL/v1/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Endur.fi protocol is accessible${NC}"
    else
        echo -e "${YELLOW}⚠ Endur.fi protocol may not be available${NC}"
    fi
    
    echo -e "${GREEN}DeFi protocol integrations setup completed${NC}"
}

# Setup monitoring and alerting
setup_monitoring() {
    echo -e "${YELLOW}Setting up monitoring and alerting...${NC}"
    
    # Test Slack webhook
    echo "Testing Slack webhook..."
    slack_payload=$(cat << EOF
{
    "text": "BitFlow monitoring setup test - $(date)",
    "channel": "#bitflow-alerts",
    "username": "BitFlow Monitor"
}
EOF
)
    
    if curl -f -X POST \
        -H "Content-Type: application/json" \
        -d "$slack_payload" \
        "$SLACK_WEBHOOK_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Slack webhook is working${NC}"
    else
        echo -e "${YELLOW}⚠ Slack webhook test failed${NC}"
    fi
    
    # Test email configuration
    echo "Testing email configuration..."
    if command -v sendmail &> /dev/null; then
        echo "Test email from BitFlow monitoring setup" | mail -s "BitFlow Setup Test" "${SMTP_USER}"
        echo -e "${GREEN}✓ Email configuration test sent${NC}"
    else
        echo -e "${YELLOW}⚠ sendmail not available, skipping email test${NC}"
    fi
    
    # Setup comprehensive monitoring configuration
    echo "Configuring monitoring stack..."
    
    # Create monitoring directories
    mkdir -p monitoring/{prometheus,grafana,alertmanager,logs}
    
    # Generate Prometheus configuration
    cat > monitoring/prometheus.yml << EOF
global:
  scrape_interval: 30s
  evaluation_interval: 30s
  external_labels:
    environment: '$ENVIRONMENT'
    service: 'bitflow'

rule_files:
  - "alert_rules.yml"

scrape_configs:
$(jq -r '.collectors.prometheus.targets[] | "  - job_name: \"\(.job)\"\n    static_configs:\n      - targets: \(.targets)\n    metrics_path: \(.metrics_path // "/metrics")\n    scrape_interval: \(.scrape_interval // "30s")"' $CONFIG_DIR/system-monitoring.json)

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093
EOF

    # Generate Alertmanager configuration
    cat > monitoring/alertmanager.yml << EOF
global:
  smtp_smarthost: '$SMTP_HOST:$SMTP_PORT'
  smtp_from: 'alerts@bitflow.app'
  slack_api_url: '$SLACK_WEBHOOK_URL'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
  - match:
      severity: critical
    receiver: critical-alerts
  - match:
      severity: warning
    receiver: warning-alerts

receivers:
- name: 'web.hook'
  webhook_configs:
  - url: '$WEBHOOK_ALERT_URL'
    http_config:
      bearer_token: '$WEBHOOK_TOKEN'

- name: 'critical-alerts'
  slack_configs:
  - channel: '#bitflow-alerts'
    title: 'Critical Alert: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
  pagerduty_configs:
  - routing_key: '$PAGERDUTY_INTEGRATION_KEY'
    description: '{{ .GroupLabels.alertname }}'

- name: 'warning-alerts'
  slack_configs:
  - channel: '#bitflow-monitoring'
    title: 'Warning: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
EOF

    # Setup log rotation
    cat > monitoring/logrotate.conf << EOF
/var/log/bitflow/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 bitflow bitflow
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
    
    echo -e "${GREEN}Monitoring and alerting setup completed${NC}"
}

# Setup API rate limiting and security
setup_api_security() {
    echo -e "${YELLOW}Setting up API rate limiting and security...${NC}"
    
    # Generate API security configuration
    cat > api/config/security.json << EOF
{
    "environment": "$ENVIRONMENT",
    "rateLimiting": $(jq '.rateLimiting' $CONFIG_DIR/api-security.json),
    "cors": $(jq ".cors.$ENVIRONMENT" $CONFIG_DIR/api-security.json),
    "authentication": $(jq '.authentication' $CONFIG_DIR/api-security.json),
    "security": $(jq '.security' $CONFIG_DIR/api-security.json)
}
EOF
    
    # Setup Redis for rate limiting
    echo "Configuring Redis for rate limiting..."
    redis-cli ping > /dev/null 2>&1 && echo -e "${GREEN}✓ Redis is running${NC}" || echo -e "${YELLOW}⚠ Redis may not be running${NC}"
    
    # Create API key for initial setup
    echo "Generating initial API key..."
    API_KEY=$(openssl rand -base64 32)
    echo "Initial API Key: $API_KEY" > api/initial-api-key.txt
    echo -e "${GREEN}✓ Initial API key generated and saved to api/initial-api-key.txt${NC}"
    
    echo -e "${GREEN}API security setup completed${NC}"
}

# Validate all integrations
validate_integrations() {
    echo -e "${YELLOW}Validating all integrations...${NC}"
    
    # Create integration test script
    cat > scripts/test-integrations.sh << 'EOF'
#!/bin/bash

echo "Running integration tests..."

# Test API health
echo -n "Testing API health... "
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "✓"
else
    echo "✗"
fi

# Test Atomiq Bridge integration
echo -n "Testing Atomiq Bridge integration... "
if curl -f -H "Authorization: Bearer $ATOMIQ_BRIDGE_API_KEY" "$ATOMIQ_API_URL/v1/health" > /dev/null 2>&1; then
    echo "✓"
else
    echo "✗"
fi

# Test database connection
echo -n "Testing database connection... "
if pg_isready -h localhost -p 5432 -U bitflow > /dev/null 2>&1; then
    echo "✓"
else
    echo "✗"
fi

# Test Redis connection
echo -n "Testing Redis connection... "
if redis-cli ping > /dev/null 2>&1; then
    echo "✓"
else
    echo "✗"
fi

echo "Integration tests completed"
EOF
    
    chmod +x scripts/test-integrations.sh
    
    echo -e "${GREEN}Integration validation setup completed${NC}"
}

# Create systemd services for monitoring
create_monitoring_services() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "${YELLOW}Creating monitoring systemd services...${NC}"
        
        # Prometheus service
        sudo tee /etc/systemd/system/bitflow-prometheus.service > /dev/null << EOF
[Unit]
Description=BitFlow Prometheus Server
After=network.target

[Service]
Type=simple
User=prometheus
WorkingDirectory=/opt/prometheus
ExecStart=/opt/prometheus/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        # Grafana service (if not using package manager)
        sudo tee /etc/systemd/system/bitflow-grafana.service > /dev/null << EOF
[Unit]
Description=BitFlow Grafana Server
After=network.target

[Service]
Type=simple
User=grafana
WorkingDirectory=/opt/grafana
ExecStart=/opt/grafana/bin/grafana-server --config=/etc/grafana/grafana.ini
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        echo -e "${GREEN}Monitoring services created${NC}"
    fi
}

# Main execution
main() {
    check_prerequisites
    setup_atomiq_bridge
    setup_defi_protocols
    setup_monitoring
    setup_api_security
    validate_integrations
    create_monitoring_services
    
    echo -e "${GREEN}External service integrations setup completed successfully!${NC}"
    echo -e "${YELLOW}Summary:${NC}"
    echo "- Atomiq Bridge integration configured and tested"
    echo "- DeFi protocol connections established"
    echo "- Monitoring and alerting configured"
    echo "- API rate limiting and security enabled"
    echo "- Integration validation scripts created"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Run integration tests: ./scripts/test-integrations.sh"
    echo "2. Start monitoring services"
    echo "3. Configure production secrets"
    echo "4. Perform load testing"
    echo ""
    echo -e "${YELLOW}Important files created:${NC}"
    echo "- api/config/security.json - API security configuration"
    echo "- api/initial-api-key.txt - Initial API key (keep secure!)"
    echo "- monitoring/targets.json - Prometheus targets"
    echo "- scripts/test-integrations.sh - Integration test script"
}

# Run main function
main "$@"