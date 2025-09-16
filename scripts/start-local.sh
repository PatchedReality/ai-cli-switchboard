#!/bin/bash
# Universal Local Model Starter with MLX + LiteLLM

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-utils.sh"

PROXY_PORT=18080

# Validate and setup config
CONFIG_FILE=$(validate_config_file "$1")
check_config_exists "$CONFIG_FILE"

# Extract model info from config
MODEL=$(grep -A2 "mlx_config:" "$CONFIG_FILE" | grep "model:" | cut -d'"' -f2)
MLX_PORT=$(grep "port:" "$CONFIG_FILE" | awk '{print $2}' | head -1)
MODEL_NAME=$(grep "name:" "$CONFIG_FILE" | cut -d'"' -f2)

if [ -z "$MODEL" ] || [ -z "$MLX_PORT" ]; then
    error "Invalid local config file: $CONFIG_FILE\nMissing model or port configuration\n\nDebug info:\n  MODEL: '$MODEL'\n  MLX_PORT: '$MLX_PORT'\n\nExpected format in config file:\n  mlx_config:\n    model: \"model-name-here\"\n    port: 18082"
fi

echo "🚀 Starting $MODEL_NAME..."
echo "📝 Model: $MODEL"
echo "📝 MLX Port: $MLX_PORT"
echo "📝 Proxy Port: $PROXY_PORT"
echo ""

# Check if ports are available and stop existing services
if is_port_in_use "$PROXY_PORT" || is_port_in_use "$MLX_PORT"; then
    log "⚠️  Required ports are in use. Stopping existing services..."
    stop_all_services
    sleep 2

    if is_port_in_use "$PROXY_PORT" || is_port_in_use "$MLX_PORT"; then
        error "Could not free required ports ($PROXY_PORT, $MLX_PORT)"
    fi
fi

# Set up environment - use current python3 configuration

# Check if model exists locally
echo "🔍 Checking model availability: $MODEL"
MODEL_EXISTS=$(python3 -c "
import os
try:
    cache_dir = os.path.expanduser('~/.cache/huggingface/hub')
    if os.path.exists(cache_dir):
        model_name = 'models--' + '$MODEL'.replace('/', '--').lower()
        model_cache_exists = any(model_name == d.lower() for d in os.listdir(cache_dir) if os.path.isdir(os.path.join(cache_dir, d)))
        print('true' if model_cache_exists else 'false')
    else:
        print('false')
except:
    print('false')
")

if [ "$MODEL_EXISTS" = "true" ]; then
    echo "✅ Model found in local cache"
    echo "📡 Starting MLX server in background on port $MLX_PORT..."
    
    # Start MLX server in background
    nohup python3 -c "
from mlx_lm.server import main
import sys
sys.argv = ['mlx_lm.server', '--model', '$MODEL', '--port', '$MLX_PORT']
main()
" > "mlx-server.log" 2>&1 &
    MLX_PID=$!
    
    # Wait for MLX server to start
    sleep 3
    
else
    echo "📦 Model not found locally - will download first"
    echo "📡 Starting MLX server in foreground (showing download progress)..."
    echo ""
    
    # Start MLX server in foreground until it's running
    python3 -c "
from mlx_lm.server import main
import sys
sys.argv = ['mlx_lm.server', '--model', '$MODEL', '--port', '$MLX_PORT']
main()
" &
    MLX_PID=$!
    
    # Wait for server to be responding (no timeout - model download can take time)
    echo ""
    echo "⏳ Waiting for server to be ready (downloading model if needed)..."
    while true; do
        if curl -s http://localhost:$MLX_PORT/v1/models > /dev/null 2>&1; then
            echo "✅ MLX server is ready! Moving to background..."
            break
        fi
        sleep 10
    done
fi

# Start LiteLLM Proxy
echo "🔄 Starting LiteLLM Proxy on port $PROXY_PORT..."
nohup python3 -c "
import sys
sys.argv = ['litellm', '--config', '$CONFIG_FILE', '--port', '$PROXY_PORT']
from litellm import run_server
run_server()
" > "litellm-proxy.log" 2>&1 &
PROXY_PID=$!

# Save PIDs and config
echo "$MLX_PID" > mlx-server.pid
echo "$PROXY_PID" > litellm-proxy.pid
echo "$CONFIG_FILE" > current-config.txt

echo ""
echo "✅ Services started successfully!"
echo "📝 MLX Server PID: $MLX_PID (port $MLX_PORT)"
echo "📝 LiteLLM Proxy PID: $PROXY_PID (port $PROXY_PORT)"
echo "📄 MLX Logs: mlx-server.log"
echo "📄 Proxy Logs: litellm-proxy.log"
echo "🌐 Claude Code URL: http://localhost:$PROXY_PORT"
echo ""
echo "To stop: ./scripts/stop.sh"
echo "To check status: ./scripts/status.sh"