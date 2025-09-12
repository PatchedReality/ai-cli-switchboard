#!/bin/bash
# Robust Remote Model Starter

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROXY_PORT=18080

# Helper functions
log() { echo "$(date '+%H:%M:%S') $1"; }
error() { log "❌ ERROR: $1" >&2; exit 1; }

# Validate arguments
CONFIG_FILE="${1:-}"
if [ -z "$CONFIG_FILE" ]; then
    error "Usage: $0 <config-file>"
fi

# Convert to absolute path
if [[ "$CONFIG_FILE" = /* ]]; then
    CONFIG_PATH="$CONFIG_FILE"
else
    CONFIG_PATH="$PROJECT_DIR/$CONFIG_FILE"
fi

if [ ! -f "$CONFIG_PATH" ]; then
    error "Config file not found: $CONFIG_PATH"
fi

# Set up Python environment
export PATH="$HOME/Library/Python/3.9/bin:$PATH"

# Load environment variables from .env file
if [ -f "$PROJECT_DIR/.env" ]; then
    log "📄 Loading environment variables from .env"
    set -a  # Mark all new/modified vars for export
    source "$PROJECT_DIR/.env"
    set +a  # Turn off auto-export
    log "✅ Loaded: DEEPSEEK_API_KEY, GEMINI_API_KEY, OPENROUTER_API_KEY"
else
    log "⚠️  No .env file found at $PROJECT_DIR/.env"
fi

# Check dependencies
if ! command -v litellm >/dev/null 2>&1; then
    error "litellm not found. Install with: pip install 'litellm[proxy]'"
fi

# Extract model info (simplified parsing)
MODEL_NAME="Unknown Model"
if grep -q "name:" "$CONFIG_PATH" 2>/dev/null; then
    MODEL_NAME=$(grep "name:" "$CONFIG_PATH" | head -1 | sed 's/.*name: *"\([^"]*\)".*/\1/')
fi

PROVIDER="Unknown Provider"
if grep -q "provider:" "$CONFIG_PATH" 2>/dev/null; then
    PROVIDER=$(grep "provider:" "$CONFIG_PATH" | head -1 | sed 's/.*provider: *"\([^"]*\)".*/\1/')
fi

log "🚀 Starting $MODEL_NAME"
log "📝 Provider: $PROVIDER"
log "📝 Port: $PROXY_PORT"

# Check if port is available
if lsof -i:$PROXY_PORT >/dev/null 2>&1; then
    log "⚠️  Port $PROXY_PORT is in use. Stopping existing services..."
    "$SCRIPT_DIR/stop.sh"
    sleep 2
    
    if lsof -i:$PROXY_PORT >/dev/null 2>&1; then
        error "Could not free port $PROXY_PORT"
    fi
fi

# Start LiteLLM Proxy
log "🔄 Starting LiteLLM Proxy..."
cd "$PROJECT_DIR"

# Explicitly export environment variables for envsubst
export DEEPSEEK_API_KEY
export GEMINI_API_KEY
export OPENROUTER_API_KEY

# Create temporary config with environment variables substituted
TEMP_CONFIG_PATH="${CONFIG_PATH}.tmp"
log "🔧 Preprocessing config with environment variables..."
envsubst < "$CONFIG_PATH" > "$TEMP_CONFIG_PATH"

nohup litellm --config "$TEMP_CONFIG_PATH" --port $PROXY_PORT \
    > litellm-proxy.log 2>&1 &
PROXY_PID=$!

# Verify process started
sleep 2
if ! kill -0 "$PROXY_PID" 2>/dev/null; then
    log "❌ Process failed to start. Log contents:"
    tail -n 20 litellm-proxy.log
    error "Failed to start LiteLLM proxy"
fi

# Save state
echo "$PROXY_PID" > litellm-proxy.pid
echo "$CONFIG_PATH" > current-config.txt
echo "$TEMP_CONFIG_PATH" > temp-config.txt

# Test connectivity (with timeout)
log "⏳ Testing connectivity..."
for i in {1..15}; do
    # Use the master key for health check
    if curl -sf -H "Authorization: Bearer dummy-key" http://localhost:$PROXY_PORT/health >/dev/null 2>&1; then
        log "✅ Service is ready!"
        break
    elif [ $i -eq 15 ]; then
        log "⚠️  Health check timed out (service may still be starting)"
        log "📄 Check logs: tail -f litellm-proxy.log"
        break
    else
        sleep 2
    fi
done

echo ""
log "✅ Started successfully!"
log "📝 PID: $PROXY_PID"
log "🌐 URL: http://localhost:$PROXY_PORT"
log "📄 Logs: tail -f litellm-proxy.log"
echo ""
log "Commands:"
log "  Stop: $SCRIPT_DIR/stop.sh"
log "  Status: $SCRIPT_DIR/status.sh"