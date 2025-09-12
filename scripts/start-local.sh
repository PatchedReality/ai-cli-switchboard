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
MODEL=$(grep "model:" "$CONFIG_FILE" | grep "mlx-community" | cut -d'"' -f2)
MLX_PORT=$(grep "port:" "$CONFIG_FILE" | cut -d' ' -f2 | head -1)
MODEL_NAME=$(grep "name:" "$CONFIG_FILE" | cut -d'"' -f2)

if [ -z "$MODEL" ] || [ -z "$MLX_PORT" ]; then
    echo "❌ Invalid local config file: $CONFIG_FILE"
    echo "Missing model or port configuration"
    exit 1
fi

echo "🚀 Starting $MODEL_NAME..."
echo "📝 Model: $MODEL"
echo "📝 MLX Port: $MLX_PORT"
echo "📝 Proxy Port: $PROXY_PORT"
echo ""

# Check if ports are available
if lsof -i:$PROXY_PORT > /dev/null 2>&1; then
    echo "⚠️  Proxy port $PROXY_PORT already in use"
    exit 1
fi

if lsof -i:$MLX_PORT > /dev/null 2>&1; then
    echo "⚠️  MLX port $MLX_PORT already in use"
    exit 1
fi

# Set up environment
export PYTHONPATH="$HOME/Library/Python/3.9/lib/python/site-packages:$PYTHONPATH"

# Start MLX server
echo "📡 Starting MLX server on port $MLX_PORT..."
nohup /usr/bin/python3 -c "
import sys
sys.path.insert(0, '$HOME/Library/Python/3.9/lib/python/site-packages')
from mlx_lm.server import main
import sys
sys.argv = ['mlx_lm.server', '--model', '$MODEL', '--port', '$MLX_PORT']
main()
" > "mlx-server.log" 2>&1 &
MLX_PID=$!

# Wait for MLX server to start
sleep 3

# Start LiteLLM Proxy
echo "🔄 Starting LiteLLM Proxy on port $PROXY_PORT..."
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
nohup litellm --config "$CONFIG_FILE" --port $PROXY_PORT > "litellm-proxy.log" 2>&1 &
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