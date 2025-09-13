#!/bin/bash
# Robust Status Checker

# Helper functions
log() { echo "$1"; }

# Check for --watch flag
WATCH_MODE=false
if [[ "$1" == "--watch" ]]; then
    WATCH_MODE=true
fi

show_status() {

echo "📊 AI Services Status"
echo "===================="

# Check current config
if [ -f "current-config.txt" ]; then
    CONFIG_FILE=$(cat current-config.txt)
    if [ -f "$CONFIG_FILE" ]; then
        MODEL_NAME="Unknown"
        if grep -q "name:" "$CONFIG_FILE" 2>/dev/null; then
            MODEL_NAME=$(grep "name:" "$CONFIG_FILE" | head -1 | sed 's/.*name: *"\([^"]*\)".*/\1/')
        fi
        log "🎯 Active: $MODEL_NAME"
        log "📄 Config: $(basename "$CONFIG_FILE")"
    else
        log "⚠️  Config file missing: $CONFIG_FILE"
    fi
    echo ""
else
    log "ℹ️  No active configuration"
    echo ""
fi

RUNNING=0

# Check LiteLLM Proxy
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

# Check MLX Server (for local models)
echo ""
echo "📡 MLX Server (Port 18081):"
if [ -f "mlx-server.pid" ]; then
    PID=$(cat mlx-server.pid)
    if kill -0 "$PID" 2>/dev/null; then
        echo "   ✅ Running (PID: $PID)"
        
        if curl -sf http://localhost:18081/v1/models >/dev/null 2>&1; then
            echo "   ✅ API responding"
            RUNNING=1
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

# Summary
echo ""
echo "===================="
if [ $RUNNING -eq 1 ]; then
    echo "🌐 Claude Code: http://localhost:18080"
    echo "✅ Ready!"
else
    echo "❌ No services running"
    echo ""
    echo "Available configs:"
    ls configs/*.yaml 2>/dev/null | while read config; do
        if [ -f "$config" ]; then
            name="Unknown"
            if grep -q "name:" "$config" 2>/dev/null; then
                name=$(grep "name:" "$config" | head -1 | sed 's/.*name: *"\([^"]*\)".*/\1/')
            fi
            echo "   📄 $(basename "$config"): $name"
        fi
    done
    echo ""
    echo "To start remote: ./scripts/start-remote-v2.sh configs/remote-gemini.yaml"
fi

}

# Main execution
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