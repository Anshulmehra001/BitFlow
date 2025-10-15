#!/bin/bash

# BitFlow Starknet Deployment Script
# This script deploys all BitFlow smart contracts to Starknet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NETWORK=${NETWORK:-"testnet"}
ACCOUNT_FILE=${ACCOUNT_FILE:-"~/.starkli/account"}
KEYSTORE_FILE=${KEYSTORE_FILE:-"~/.starkli/keystore"}
RPC_URL=${RPC_URL:-"https://starknet-testnet.public.blastapi.io"}

echo -e "${GREEN}Starting BitFlow deployment to $NETWORK...${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    if ! command -v scarb &> /dev/null; then
        echo -e "${RED}Error: scarb is not installed${NC}"
        exit 1
    fi
    
    if ! command -v starkli &> /dev/null; then
        echo -e "${RED}Error: starkli is not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Prerequisites check passed${NC}"
}

# Build contracts
build_contracts() {
    echo -e "${YELLOW}Building contracts...${NC}"
    scarb build
    echo -e "${GREEN}Contracts built successfully${NC}"
}

# Deploy contracts in dependency order
deploy_contracts() {
    echo -e "${YELLOW}Deploying contracts...${NC}"
    
    # Create deployment log
    DEPLOYMENT_LOG="deployments/deployment_$(date +%Y%m%d_%H%M%S).log"
    mkdir -p deployments
    
    echo "BitFlow Deployment Log - $(date)" > $DEPLOYMENT_LOG
    echo "Network: $NETWORK" >> $DEPLOYMENT_LOG
    echo "RPC URL: $RPC_URL" >> $DEPLOYMENT_LOG
    echo "=================================" >> $DEPLOYMENT_LOG
    
    # Deploy EscrowManager first (no dependencies)
    echo -e "${YELLOW}Deploying EscrowManager...${NC}"
    ESCROW_ADDRESS=$(starkli deploy \
        --rpc $RPC_URL \
        --account $ACCOUNT_FILE \
        --keystore $KEYSTORE_FILE \
        target/dev/bitflow_EscrowManager.contract_class.json \
        2>&1 | grep "Contract deployed:" | cut -d' ' -f3)
    
    if [ -z "$ESCROW_ADDRESS" ]; then
        echo -e "${RED}Failed to deploy EscrowManager${NC}"
        exit 1
    fi
    
    echo "EscrowManager deployed at: $ESCROW_ADDRESS" | tee -a $DEPLOYMENT_LOG
    
    # Deploy AtomiqBridgeAdapter
    echo -e "${YELLOW}Deploying AtomiqBridgeAdapter...${NC}"
    BRIDGE_ADDRESS=$(starkli deploy \
        --rpc $RPC_URL \
        --account $ACCOUNT_FILE \
        --keystore $KEYSTORE_FILE \
        target/dev/bitflow_AtomiqBridgeAdapter.contract_class.json \
        $ESCROW_ADDRESS \
        2>&1 | grep "Contract deployed:" | cut -d' ' -f3)
    
    echo "AtomiqBridgeAdapter deployed at: $BRIDGE_ADDRESS" | tee -a $DEPLOYMENT_LOG
    
    # Deploy YieldManager
    echo -e "${YELLOW}Deploying YieldManager...${NC}"
    YIELD_ADDRESS=$(starkli deploy \
        --rpc $RPC_URL \
        --account $ACCOUNT_FILE \
        --keystore $KEYSTORE_FILE \
        target/dev/bitflow_YieldManager.contract_class.json \
        2>&1 | grep "Contract deployed:" | cut -d' ' -f3)
    
    echo "YieldManager deployed at: $YIELD_ADDRESS" | tee -a $DEPLOYMENT_LOG
    
    # Deploy StreamManager (depends on EscrowManager, BridgeAdapter, YieldManager)
    echo -e "${YELLOW}Deploying StreamManager...${NC}"
    STREAM_ADDRESS=$(starkli deploy \
        --rpc $RPC_URL \
        --account $ACCOUNT_FILE \
        --keystore $KEYSTORE_FILE \
        target/dev/bitflow_StreamManager.contract_class.json \
        $ESCROW_ADDRESS \
        $BRIDGE_ADDRESS \
        $YIELD_ADDRESS \
        2>&1 | grep "Contract deployed:" | cut -d' ' -f3)
    
    echo "StreamManager deployed at: $STREAM_ADDRESS" | tee -a $DEPLOYMENT_LOG
    
    # Deploy SubscriptionManager
    echo -e "${YELLOW}Deploying SubscriptionManager...${NC}"
    SUBSCRIPTION_ADDRESS=$(starkli deploy \
        --rpc $RPC_URL \
        --account $ACCOUNT_FILE \
        --keystore $KEYSTORE_FILE \
        target/dev/bitflow_SubscriptionManager.contract_class.json \
        $STREAM_ADDRESS \
        2>&1 | grep "Contract deployed:" | cut -d' ' -f3)
    
    echo "SubscriptionManager deployed at: $SUBSCRIPTION_ADDRESS" | tee -a $DEPLOYMENT_LOG
    
    # Deploy MicroPaymentManager
    echo -e "${YELLOW}Deploying MicroPaymentManager...${NC}"
    MICROPAYMENT_ADDRESS=$(starkli deploy \
        --rpc $RPC_URL \
        --account $ACCOUNT_FILE \
        --keystore $KEYSTORE_FILE \
        target/dev/bitflow_MicroPaymentManager.contract_class.json \
        $STREAM_ADDRESS \
        2>&1 | grep "Contract deployed:" | cut -d' ' -f3)
    
    echo "MicroPaymentManager deployed at: $MICROPAYMENT_ADDRESS" | tee -a $DEPLOYMENT_LOG
    
    # Deploy SystemMonitor
    echo -e "${YELLOW}Deploying SystemMonitor...${NC}"
    MONITOR_ADDRESS=$(starkli deploy \
        --rpc $RPC_URL \
        --account $ACCOUNT_FILE \
        --keystore $KEYSTORE_FILE \
        target/dev/bitflow_SystemMonitor.contract_class.json \
        2>&1 | grep "Contract deployed:" | cut -d' ' -f3)
    
    echo "SystemMonitor deployed at: $MONITOR_ADDRESS" | tee -a $DEPLOYMENT_LOG
    
    # Generate deployment configuration
    generate_deployment_config
    
    echo -e "${GREEN}All contracts deployed successfully!${NC}"
    echo -e "${GREEN}Deployment log saved to: $DEPLOYMENT_LOG${NC}"
}

# Generate deployment configuration file
generate_deployment_config() {
    echo -e "${YELLOW}Generating deployment configuration...${NC}"
    
    cat > deployments/contracts.json << EOF
{
  "network": "$NETWORK",
  "rpc_url": "$RPC_URL",
  "deployment_date": "$(date -Iseconds)",
  "contracts": {
    "EscrowManager": "$ESCROW_ADDRESS",
    "AtomiqBridgeAdapter": "$BRIDGE_ADDRESS",
    "YieldManager": "$YIELD_ADDRESS",
    "StreamManager": "$STREAM_ADDRESS",
    "SubscriptionManager": "$SUBSCRIPTION_ADDRESS",
    "MicroPaymentManager": "$MICROPAYMENT_ADDRESS",
    "SystemMonitor": "$MONITOR_ADDRESS"
  }
}
EOF
    
    echo -e "${GREEN}Deployment configuration saved to deployments/contracts.json${NC}"
}

# Main execution
main() {
    check_prerequisites
    build_contracts
    deploy_contracts
    
    echo -e "${GREEN}BitFlow deployment completed successfully!${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Update environment variables with deployed contract addresses"
    echo "2. Configure external service integrations"
    echo "3. Set up monitoring and alerting"
}

# Run main function
main "$@"