#!/bin/bash
# Robust Remote Model Starter

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-utils.sh"

PROXY_PORT=18080

# Validate and setup config
CONFIG_PATH=$(validate_config_file "$1")
check_config_exists "$CONFIG_PATH"

# Setup environment
setup_python_env
load_env_file

# Check dependencies
require_command "litellm" "Install with: pip3 install 'litellm[proxy]'"

# Extract model info using shared function
if get_config_metadata "$CONFIG_PATH"; then
    MODEL_NAME="$CONFIG_NAME"
    PROVIDER=$(get_yaml_value "$CONFIG_PATH" "provider" || echo "Unknown Provider")
else
    MODEL_NAME="Unknown Model"
    PROVIDER="Unknown Provider"
fi

log_with_time "🚀 Starting $MODEL_NAME"
log_with_time "📝 Provider: $PROVIDER"
log_with_time "📝 Port: $PROXY_PORT"

# Check if port is available and stop existing services
if is_port_in_use "$PROXY_PORT"; then
    log_with_time "⚠️  Port $PROXY_PORT is in use. Stopping existing services..."
    stop_all_services
    sleep 2

    if ! wait_for_port_free "$PROXY_PORT" 5; then
        error "Could not free port $PROXY_PORT"
    fi
fi

# Start LiteLLM Proxy
log_with_time "🔄 Starting LiteLLM Proxy..."
cd "$PROJECT_DIR"

# Explicitly export environment variables for envsubst
export DEEPSEEK_API_KEY
export GEMINI_API_KEY
export OPENROUTER_API_KEY
export ZAI_API_KEY

# Create temporary config with environment variables substituted
TEMP_CONFIG_PATH="${CONFIG_PATH}.tmp"
log_with_time "🔧 Preprocessing config with environment variables..."
envsubst < "$CONFIG_PATH" > "$TEMP_CONFIG_PATH"

nohup litellm --config "$TEMP_CONFIG_PATH" --port $PROXY_PORT \
    > litellm-proxy.log 2>&1 &
PROXY_PID=$!

# Verify process started
sleep 2
if ! is_process_running "$PROXY_PID"; then
    log_with_time "❌ Process failed to start. Log contents:"
    tail -n 20 litellm-proxy.log
    error "Failed to start LiteLLM proxy"
fi

# Save state
echo "$PROXY_PID" > litellm-proxy.pid
echo "$CONFIG_PATH" > current-config.txt
echo "$TEMP_CONFIG_PATH" > temp-config.txt

# Test connectivity (with timeout)
log_with_time "⏳ Testing connectivity..."
for i in {1..15}; do
    # Use the master key for health check
    if curl -sf -H "Authorization: Bearer dummy-key" http://localhost:$PROXY_PORT/health >/dev/null 2>&1; then
        log_with_time "✅ Service is ready!"
        break
    elif [ $i -eq 15 ]; then
        log_with_time "⚠️  Health check timed out (service may still be starting)"
        log_with_time "📄 Check logs: tail -f litellm-proxy.log"
        break
    else
        sleep 2
    fi
done

echo ""
log_with_time "✅ Started successfully!"
log_with_time "📝 PID: $PROXY_PID"
log_with_time "🌐 URL: http://localhost:$PROXY_PORT"
log_with_time "📄 Logs: tail -f litellm-proxy.log"
echo ""
log_with_time "Commands:"
log_with_time "  Stop: $SCRIPT_DIR/stop.sh"
log_with_time "  Status: $SCRIPT_DIR/status.sh"