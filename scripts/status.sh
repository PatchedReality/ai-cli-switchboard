#!/bin/bash
# Comprehensive Status Checker for Multi-Model AI Assistant

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-utils.sh"

# Check for flags
WATCH_MODE=false
WAIT_MODE=false
if [[ "$1" == "--watch" ]]; then
    WATCH_MODE=true
elif [[ "$1" == "--wait" ]]; then
    WAIT_MODE=true
fi

show_status() {

echo "📊 AI Services Status"
echo "===================="

# Check current config
if [ -f "current-config.txt" ]; then
    CONFIG_FILE=$(cat current-config.txt)
    if [ -f "$CONFIG_FILE" ]; then
        if get_config_metadata "$CONFIG_FILE"; then
            log "🎯 Active: $CONFIG_NAME"
            if [ -n "$CONFIG_DESCRIPTION" ]; then
                log "📋 Info: $CONFIG_DESCRIPTION"
            fi
            log "🔧 Type: $CONFIG_RUNNER_TYPE"
            log "📄 Config: $(basename "$CONFIG_FILE")"
        else
            log "🎯 Active: $(get_yaml_value "$CONFIG_FILE" "name" || echo "Unknown")"
            log "📄 Config: $(basename "$CONFIG_FILE")"
        fi
    else
        log "⚠️  Config file missing: $CONFIG_FILE"
    fi
    echo ""
else
    log "ℹ️  No active configuration"
    echo ""
fi

RUNNING=0

# Check LiteLLM Proxy (main proxy for all models)
echo "🔄 LiteLLM Proxy (Port 18080):"
if [ -f "litellm-proxy.pid" ]; then
    PID=$(cat litellm-proxy.pid)
    if kill -0 "$PID" 2>/dev/null; then
        echo "   ✅ Running (PID: $PID)"

        # Test API
        if curl -sf -H "Authorization: Bearer dummy-key" http://localhost:18080/health >/dev/null 2>&1; then
            echo "   ✅ API responding"
            RUNNING=1
        else
            echo "   ⚠️  API not responding"
        fi
    else
        echo "   ❌ Not running (stale PID)"
        rm -f litellm-proxy.pid
    fi
else
    echo "   ❌ Not running"
fi

# Check MLX Server (for local MLX models)
echo ""
echo "📡 MLX Server (Port 18081):"
if [ -f "mlx-server.pid" ]; then
    PID=$(cat mlx-server.pid)
    if kill -0 "$PID" 2>/dev/null; then
        echo "   ✅ Running (PID: $PID)"

        if curl -sf http://localhost:18081/v1/models >/dev/null 2>&1; then
            echo "   ✅ API responding"
        else
            echo "   ⚠️  API not responding (may be loading)"
        fi
    else
        echo "   ❌ Not running (stale PID)"
        rm -f mlx-server.pid
    fi
else
    echo "   ❌ Not running"
fi

# Check LM Studio Server (for local LM Studio models)
echo ""
echo "🏪 LM Studio Server (Port 1234):"
LMS_PATH="$HOME/.lmstudio/bin/lms"
if [ -f "$LMS_PATH" ]; then
    chmod +x "$LMS_PATH"
    if lsof -i:1234 >/dev/null 2>&1; then
        echo "   ✅ Running"

        if curl -sf http://localhost:1234/v1/models >/dev/null 2>&1; then
            echo "   ✅ API responding"

            # Show loaded models
            LOADED_MODELS=$("$LMS_PATH" ps 2>/dev/null | grep -v "No models loaded" || echo "")
            if [ -n "$LOADED_MODELS" ]; then
                echo "   📦 Loaded models:"
                echo "$LOADED_MODELS" | while read line; do
                    if [ -n "$line" ]; then
                        echo "      • $line"
                    fi
                done
            else
                echo "   📦 No models loaded"
            fi
        else
            echo "   ⚠️  API not responding"
        fi
    else
        echo "   ❌ Not running"
    fi
else
    echo "   ❌ LM Studio CLI not found"
fi

# Summary
echo ""
echo "===================="
if [ $RUNNING -eq 1 ]; then
    echo "🌐 Claude Code endpoint: http://localhost:18080"
    echo "🖥️  Use: claudel"
    echo "✅ Ready!"
else
    echo "❌ Main proxy not running"
    echo ""
fi

}

# Wait mode - wait for services to be ready
if [[ "$WAIT_MODE" == true ]]; then
    echo "⏳ Waiting for services to be ready..."
    echo ""

    MAX_WAIT=60  # Maximum wait time in seconds
    WAIT_COUNT=0

    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        show_status

        # Check if main proxy is responding
        if curl -sf -H "Authorization: Bearer dummy-key" http://localhost:18080/health >/dev/null 2>&1; then
            echo ""
            echo "✅ Services are ready!"
            exit 0
        fi

        echo ""
        echo "⏳ Waiting... (${WAIT_COUNT}s/${MAX_WAIT}s)"
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 2))

        if [ $WAIT_COUNT -lt $MAX_WAIT ]; then
            clear
        fi
    done

    error "Timeout reached. Services may still be starting.\n   Use 'scripts/status.sh --watch' to monitor progress."
fi

# Watch mode
if [[ "$WATCH_MODE" == true ]]; then
    echo "🔄 Watching status... (Press Ctrl+C to exit)"
    echo ""
    while true; do
        clear
        show_status
        echo ""
        echo "$(date '+%H:%M:%S') - Refreshing every 3 seconds..."
        sleep 3
    done
else
    show_status
fi