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
    echo "Available configurations:"

    # Use categorized config display
    categorize_configs "status"

    # Helper function to display config entries
    display_config_group() {
        local group_name="$1"
        local emoji="$2"
        local array_name="$3"

        local array_size=$(eval "echo \${#${array_name}[@]}")
        if [ "$array_size" -gt 0 ]; then
            echo ""
            echo "$emoji $group_name:"

            eval "configs=(\"\${${array_name}[@]}\")"
            for entry in "${configs[@]}"; do
                parse_config_entry "$entry" "config"
                config_line="   📄 $config_basename: $config_name"
                if [ -n "$config_alias_name" ]; then
                    config_line="$config_line (alias: $config_alias_name)"
                fi
                echo "$config_line"
            done
        fi
    }

    display_config_group "Local MLX Models" "🏠" "status_local_mlx"
    display_config_group "Local LM Studio Models" "🏪" "status_local_lmstudio"
    display_config_group "Remote Models" "☁️" "status_remote_litellm"
    display_config_group "Remote Z.AI Models" "🔗" "status_remote_zai"

    echo ""
    echo "🚀 To start:"
    echo "   Remote: ./scripts/start-remote.sh configs/remote-deepseek.yaml"
    echo "   Local:  ./scripts/start-local.sh configs/local-glm-9b.yaml"
    echo "   LM Studio: ./scripts/start-lmstudio.sh configs/lmstudio-llama-groq-tool.yaml"
    echo "   Or use aliases: source ai-aliases.sh && claude-models"
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