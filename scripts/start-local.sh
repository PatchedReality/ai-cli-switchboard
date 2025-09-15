#!/bin/bash
# Universal Local Model Starter with MLX + LiteLLM

set -e

CONFIG_FILE="$1"
PROXY_PORT=18080

# Validate arguments
if [ -z "$CONFIG_FILE" ]; then
    echo "Usage: $0 <config-file>"
    echo "Example: $0 configs/local-glm-9b.yaml"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

# Extract model info from config
MODEL=$(grep -A2 "mlx_config:" "$CONFIG_FILE" | grep "model:" | cut -d'"' -f2)
MLX_PORT=$(grep "port:" "$CONFIG_FILE" | awk '{print $2}' | head -1)
MODEL_NAME=$(grep "name:" "$CONFIG_FILE" | cut -d'"' -f2)

if [ -z "$MODEL" ] || [ -z "$MLX_PORT" ]; then
    echo "❌ Invalid local config file: $CONFIG_FILE" >&2
    echo "Missing model or port configuration" >&2
    echo "" >&2
    echo "Debug info:" >&2
    echo "  MODEL: '$MODEL'" >&2
    echo "  MLX_PORT: '$MLX_PORT'" >&2
    echo "" >&2
    echo "Expected format in config file:" >&2
    echo "  mlx_config:" >&2
    echo "    model: \"model-name-here\"" >&2
    echo "    port: 18082" >&2
    exit 1
fi

echo "🚀 Starting $MODEL_NAME..."
echo "📝 Model: $MODEL"
echo "📝 MLX Port: $MLX_PORT"
echo "📝 Proxy Port: $PROXY_PORT"
echo ""

# Check if ports are available and stop existing services
if lsof -i:$PROXY_PORT > /dev/null 2>&1; then
    echo "⚠️  Port $PROXY_PORT is in use. Stopping existing services..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "$SCRIPT_DIR/stop.sh"
    sleep 2
fi

if lsof -i:$MLX_PORT > /dev/null 2>&1; then
    echo "⚠️  MLX port $MLX_PORT already in use (likely from previous MLX server)"
    echo "   Stopping existing services..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "$SCRIPT_DIR/stop.sh"
    sleep 2
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