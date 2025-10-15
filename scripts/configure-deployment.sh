#!/bin/bash

# BitFlow Deployment Configuration Script
# This script configures the deployment environment after contract deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DEPLOYMENT_CONFIG="deployments/contracts.json"
ENV_FILE=".env"

echo -e "${GREEN}Configuring BitFlow deployment environment...${NC}"

# Check if deployment config exists
if [ ! -f "$DEPLOYMENT_CONFIG" ]; then
    echo -e "${RED}Error: Deployment configuration not found at $DEPLOYMENT_CONFIG${NC}"
    echo "Please run the deployment script first."
    exit 1
fi

# Extract contract addresses from deployment config
extract_addresses() {
    echo -e "${YELLOW}Extracting contract addresses...${NC}"
    
    ESCROW_ADDRESS=$(jq -r '.contracts.EscrowManager' $DEPLOYMENT_CONFIG)
    BRIDGE_ADDRESS=$(jq -r '.contracts.AtomiqBridgeAdapter' $DEPLOYMENT_CONFIG)
    YIELD_ADDRESS=$(jq -r '.contracts.YieldManager' $DEPLOYMENT_CONFIG)
    STREAM_ADDRESS=$(jq -r '.contracts.StreamManager' $DEPLOYMENT_CONFIG)
    SUBSCRIPTION_ADDRESS=$(jq -r '.contracts.SubscriptionManager' $DEPLOYMENT_CONFIG)
    MICROPAYMENT_ADDRESS=$(jq -r '.contracts.MicroPaymentManager' $DEPLOYMENT_CONFIG)
    MONITOR_ADDRESS=$(jq -r '.contracts.SystemMonitor' $DEPLOYMENT_CONFIG)
    
    echo -e "${GREEN}Contract addresses extracted successfully${NC}"
}

# Update environment file with contract addresses
update_env_file() {
    echo -e "${YELLOW}Updating environment file...${NC}"
    
    # Create backup of current env file
    cp $ENV_FILE "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update contract addresses
    sed -i "s/^ESCROW_MANAGER_ADDRESS=.*/ESCROW_MANAGER_ADDRESS=$ESCROW_ADDRESS/" $ENV_FILE
    sed -i "s/^ATOMIQ_BRIDGE_ADAPTER_ADDRESS=.*/ATOMIQ_BRIDGE_ADAPTER_ADDRESS=$BRIDGE_ADDRESS/" $ENV_FILE
    sed -i "s/^YIELD_MANAGER_ADDRESS=.*/YIELD_MANAGER_ADDRESS=$YIELD_ADDRESS/" $ENV_FILE
    sed -i "s/^STREAM_MANAGER_ADDRESS=.*/STREAM_MANAGER_ADDRESS=$STREAM_ADDRESS/" $ENV_FILE
    sed -i "s/^SUBSCRIPTION_MANAGER_ADDRESS=.*/SUBSCRIPTION_MANAGER_ADDRESS=$SUBSCRIPTION_ADDRESS/" $ENV_FILE
    sed -i "s/^MICRO_PAYMENT_MANAGER_ADDRESS=.*/MICRO_PAYMENT_MANAGER_ADDRESS=$MICROPAYMENT_ADDRESS/" $ENV_FILE
    sed -i "s/^SYSTEM_MONITOR_ADDRESS=.*/SYSTEM_MONITOR_ADDRESS=$MONITOR_ADDRESS/" $ENV_FILE
    
    echo -e "${GREEN}Environment file updated successfully${NC}"
}

# Generate API configuration
generate_api_config() {
    echo -e "${YELLOW}Generating API configuration...${NC}"
    
    cat > api/config/contracts.json << EOF
{
  "network": "$(jq -r '.network' $DEPLOYMENT_CONFIG)",
  "rpc_url": "$(jq -r '.rpc_url' $DEPLOYMENT_CONFIG)",
  "contracts": {
    "escrowManager": "$ESCROW_ADDRESS",
    "atomiqBridgeAdapter": "$BRIDGE_ADDRESS",
    "yieldManager": "$YIELD_ADDRESS",
    "streamManager": "$STREAM_ADDRESS",
    "subscriptionManager": "$SUBSCRIPTION_ADDRESS",
    "microPaymentManager": "$MICROPAYMENT_ADDRESS",
    "systemMonitor": "$MONITOR_ADDRESS"
  }
}
EOF
    
    echo -e "${GREEN}API configuration generated${NC}"
}

# Generate web app configuration
generate_web_config() {
    echo -e "${YELLOW}Generating web app configuration...${NC}"
    
    cat > web/src/config/contracts.ts << EOF
// Auto-generated contract configuration
export const CONTRACT_ADDRESSES = {
  ESCROW_MANAGER: '$ESCROW_ADDRESS',
  ATOMIQ_BRIDGE_ADAPTER: '$BRIDGE_ADDRESS',
  YIELD_MANAGER: '$YIELD_ADDRESS',
  STREAM_MANAGER: '$STREAM_ADDRESS',
  SUBSCRIPTION_MANAGER: '$SUBSCRIPTION_ADDRESS',
  MICRO_PAYMENT_MANAGER: '$MICROPAYMENT_ADDRESS',
  SYSTEM_MONITOR: '$MONITOR_ADDRESS',
} as const;

export const NETWORK_CONFIG = {
  NETWORK: '$(jq -r '.network' $DEPLOYMENT_CONFIG)',
  RPC_URL: '$(jq -r '.rpc_url' $DEPLOYMENT_CONFIG)',
} as const;
EOF
    
    echo -e "${GREEN}Web app configuration generated${NC}"
}

# Generate mobile app configuration
generate_mobile_config() {
    echo -e "${YELLOW}Generating mobile app configuration...${NC}"
    
    cat > mobile/src/config/contracts.ts << EOF
// Auto-generated contract configuration
export const CONTRACT_ADDRESSES = {
  ESCROW_MANAGER: '$ESCROW_ADDRESS',
  ATOMIQ_BRIDGE_ADAPTER: '$BRIDGE_ADDRESS',
  YIELD_MANAGER: '$YIELD_ADDRESS',
  STREAM_MANAGER: '$STREAM_ADDRESS',
  SUBSCRIPTION_MANAGER: '$SUBSCRIPTION_ADDRESS',
  MICRO_PAYMENT_MANAGER: '$MICROPAYMENT_ADDRESS',
  SYSTEM_MONITOR: '$MONITOR_ADDRESS',
} as const;

export const NETWORK_CONFIG = {
  NETWORK: '$(jq -r '.network' $DEPLOYMENT_CONFIG)',
  RPC_URL: '$(jq -r '.rpc_url' $DEPLOYMENT_CONFIG)',
} as const;
EOF
    
    echo -e "${GREEN}Mobile app configuration generated${NC}"
}

# Generate SDK configuration
generate_sdk_config() {
    echo -e "${YELLOW}Generating SDK configuration...${NC}"
    
    # JavaScript SDK
    cat > sdk/javascript/src/config.ts << EOF
// Auto-generated contract configuration
export const DEFAULT_CONTRACT_ADDRESSES = {
  ESCROW_MANAGER: '$ESCROW_ADDRESS',
  ATOMIQ_BRIDGE_ADAPTER: '$BRIDGE_ADDRESS',
  YIELD_MANAGER: '$YIELD_ADDRESS',
  STREAM_MANAGER: '$STREAM_ADDRESS',
  SUBSCRIPTION_MANAGER: '$SUBSCRIPTION_ADDRESS',
  MICRO_PAYMENT_MANAGER: '$MICROPAYMENT_ADDRESS',
  SYSTEM_MONITOR: '$MONITOR_ADDRESS',
} as const;

export const DEFAULT_NETWORK_CONFIG = {
  NETWORK: '$(jq -r '.network' $DEPLOYMENT_CONFIG)',
  RPC_URL: '$(jq -r '.rpc_url' $DEPLOYMENT_CONFIG)',
} as const;
EOF
    
    # Python SDK
    cat > sdk/python/bitflow/config.py << EOF
# Auto-generated contract configuration
DEFAULT_CONTRACT_ADDRESSES = {
    'ESCROW_MANAGER': '$ESCROW_ADDRESS',
    'ATOMIQ_BRIDGE_ADAPTER': '$BRIDGE_ADDRESS',
    'YIELD_MANAGER': '$YIELD_ADDRESS',
    'STREAM_MANAGER': '$STREAM_ADDRESS',
    'SUBSCRIPTION_MANAGER': '$SUBSCRIPTION_ADDRESS',
    'MICRO_PAYMENT_MANAGER': '$MICROPAYMENT_ADDRESS',
    'SYSTEM_MONITOR': '$MONITOR_ADDRESS',
}

DEFAULT_NETWORK_CONFIG = {
    'NETWORK': '$(jq -r '.network' $DEPLOYMENT_CONFIG)',
    'RPC_URL': '$(jq -r '.rpc_url' $DEPLOYMENT_CONFIG)',
}
EOF
    
    echo -e "${GREEN}SDK configuration generated${NC}"
}

# Verify contract deployment
verify_contracts() {
    echo -e "${YELLOW}Verifying contract deployment...${NC}"
    
    RPC_URL=$(jq -r '.rpc_url' $DEPLOYMENT_CONFIG)
    
    # Check each contract
    contracts=("$ESCROW_ADDRESS" "$BRIDGE_ADDRESS" "$YIELD_ADDRESS" "$STREAM_ADDRESS" "$SUBSCRIPTION_ADDRESS" "$MICROPAYMENT_ADDRESS" "$MONITOR_ADDRESS")
    contract_names=("EscrowManager" "AtomiqBridgeAdapter" "YieldManager" "StreamManager" "SubscriptionManager" "MicroPaymentManager" "SystemMonitor")
    
    for i in "${!contracts[@]}"; do
        address="${contracts[$i]}"
        name="${contract_names[$i]}"
        
        echo -n "Checking $name at $address... "
        
        # Try to call a basic function to verify deployment
        if starkli call --rpc $RPC_URL $address get_version 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
            echo -e "${RED}Warning: $name may not be properly deployed${NC}"
        fi
    done
    
    echo -e "${GREEN}Contract verification completed${NC}"
}

# Setup monitoring configuration
setup_monitoring() {
    echo -e "${YELLOW}Setting up monitoring configuration...${NC}"
    
    # Update Prometheus configuration with contract addresses
    sed -i "s/CONTRACT_ADDRESSES_PLACEHOLDER/$STREAM_ADDRESS,$ESCROW_ADDRESS,$BRIDGE_ADDRESS/" monitoring/prometheus.yml
    
    # Create systemd service files if on Linux
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        create_systemd_services
    fi
    
    echo -e "${GREEN}Monitoring configuration completed${NC}"
}

# Create systemd service files
create_systemd_services() {
    echo -e "${YELLOW}Creating systemd service files...${NC}"
    
    # BitFlow API service
    sudo tee /etc/systemd/system/bitflow-api.service > /dev/null << EOF
[Unit]
Description=BitFlow API Server
After=network.target

[Service]
Type=simple
User=bitflow
WorkingDirectory=/opt/bitflow/api
Environment=NODE_ENV=production
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start services
    sudo systemctl daemon-reload
    sudo systemctl enable bitflow-api
    
    echo -e "${GREEN}Systemd services created${NC}"
}

# Main execution
main() {
    extract_addresses
    update_env_file
    generate_api_config
    generate_web_config
    generate_mobile_config
    generate_sdk_config
    verify_contracts
    setup_monitoring
    
    echo -e "${GREEN}Deployment configuration completed successfully!${NC}"
    echo -e "${YELLOW}Summary:${NC}"
    echo "- Environment file updated with contract addresses"
    echo "- API, web, mobile, and SDK configurations generated"
    echo "- Contract deployment verified"
    echo "- Monitoring configuration updated"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review generated configuration files"
    echo "2. Start application services"
    echo "3. Run integration tests"
    echo "4. Configure external service integrations"
}

# Run main function
main "$@"