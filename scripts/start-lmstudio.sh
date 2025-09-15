#!/bin/bash
# LM Studio Model Server Startup Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if config file provided
if [ -z "$1" ]; then
    echo "❌ Error: No configuration file provided"
    echo "Usage: $0 <config-file>"
    exit 1
fi

CONFIG_FILE="$1"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Check if LM Studio CLI is available
LMS_PATH="$HOME/.lmstudio/bin/lms"
if [ ! -f "$LMS_PATH" ]; then
    echo "❌ Error: LM Studio CLI not found at $LMS_PATH"
    echo "Please install LM Studio and run it at least once to set up the CLI"
    echo "Download from: https://lmstudio.ai/"
    exit 1
fi

# Make lms executable if needed
chmod +x "$LMS_PATH"

echo "🚀 Starting LM Studio model server..."

# Stop existing services first
echo "🛑 Stopping existing services..."
"$SCRIPT_DIR/stop.sh" >/dev/null 2>&1 || true

# Extract model info from config
MODEL_KEY=$(grep "model_key:" "$CONFIG_FILE" | head -1 | sed 's/.*model_key: *"\([^"]*\)".*/\1/')
MODEL_NAME=$(grep "model_name:" "$CONFIG_FILE" | head -1 | sed 's/.*model_name: *\([^ ]*\).*/\1/')

if [ -z "$MODEL_KEY" ]; then
    echo "❌ Error: Could not find model_key in config file"
    exit 1
fi

echo "📦 Model: $MODEL_NAME"
echo "🔑 Key: $MODEL_KEY"

# Check if model is downloaded
echo "📋 Checking available models..."
if ! "$LMS_PATH" ls | grep -q "$MODEL_KEY"; then
    echo "❌ Error: Model '$MODEL_KEY' not found in LM Studio"
    echo ""
    echo "Available models:"
    "$LMS_PATH" ls
    echo ""
    echo "Please download the model using LM Studio GUI first"
    exit 1
fi

# Unload any existing models
echo "🧹 Unloading existing models..."
"$LMS_PATH" unload --all >/dev/null 2>&1 || true

# Load the specified model
echo "📥 Loading model: $MODEL_KEY"
"$LMS_PATH" load "$MODEL_KEY" --gpu max --context-length 32768

# Start LM Studio server
echo "🌐 Starting LM Studio server..."
"$LMS_PATH" server start

# Wait for server to be ready
echo "⏳ Waiting for LM Studio server to be ready..."
for i in {1..30}; do
    if nc -z 127.0.0.1 1234 2>/dev/null; then
        echo "✅ LM Studio server is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Error: LM Studio server failed to start"
        exit 1
    fi
    sleep 1
done

# Start LiteLLM proxy
echo "🔄 Starting LiteLLM proxy..."
cd "$PROJECT_DIR"

# Set up Python environment (like other scripts)
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)
export PATH="$HOME/Library/Python/$PYTHON_VERSION/bin:$PATH"

# Load environment variables from .env file if it exists
if [ -f "$PROJECT_DIR/.env" ]; then
    echo "📄 Loading environment variables from .env"
    set -a  # Mark all new/modified vars for export
    source "$PROJECT_DIR/.env"
    set +a  # Turn off auto-export
fi

# Save current config for status script
echo "$CONFIG_FILE" > current-config.txt

# Start LiteLLM using Python method (like start-local.sh)
PROXY_PORT=18080
nohup python3 -c "
import sys
sys.argv = ['litellm', '--config', '$CONFIG_FILE', '--port', '$PROXY_PORT']
from litellm import run_server
run_server()
" > litellm-proxy.log 2>&1 &
LITELLM_PID=$!
echo $LITELLM_PID > litellm-proxy.pid

# Wait for LiteLLM to be ready
echo "⏳ Waiting for LiteLLM proxy to be ready..."
for i in {1..30}; do
    if curl -sf -H "Authorization: Bearer dummy-key" http://localhost:18080/health >/dev/null 2>&1; then
        echo "✅ LiteLLM proxy is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Error: LiteLLM proxy failed to start"
        kill $LITELLM_PID 2>/dev/null || true
        "$LMS_PATH" server stop >/dev/null 2>&1 || true
        exit 1
    fi
    sleep 1
done

echo ""
echo "🎉 Successfully started LM Studio + LiteLLM setup!"
echo "🌐 Claude Code: http://localhost:18080"
echo "📊 Status: ./scripts/status.sh"
echo "🛑 Stop: ./scripts/stop.sh"
echo ""
echo "💡 Use: ANTHROPIC_BASE_URL=http://localhost:18080 ANTHROPIC_API_KEY=dummy-key claude"