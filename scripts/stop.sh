#!/bin/bash
# Universal Stop Script for All Model Types

echo "🛑 Stopping all AI services..."

STOPPED=0

# Stop LiteLLM Proxy
if [ -f "litellm-proxy.pid" ]; then
    PROXY_PID=$(cat litellm-proxy.pid)
    if kill -0 "$PROXY_PID" 2>/dev/null; then
        echo "📝 Stopping LiteLLM Proxy (PID: $PROXY_PID)..."
        kill "$PROXY_PID"
        STOPPED=1
    fi
    rm -f litellm-proxy.pid
fi

# Stop MLX Server (for local models)
if [ -f "mlx-server.pid" ]; then
    MLX_PID=$(cat mlx-server.pid)
    if kill -0 "$MLX_PID" 2>/dev/null; then
        echo "📝 Stopping MLX Server (PID: $MLX_PID)..."
        kill "$MLX_PID"
        STOPPED=1
    fi
    rm -f mlx-server.pid
fi

# Clean up legacy PID files
for pid_file in glm-*.pid; do
    if [ -f "$pid_file" ]; then
        PID=$(cat "$pid_file")
        if kill -0 "$PID" 2>/dev/null; then
            echo "📝 Stopping legacy service (PID: $PID)..."
            kill "$PID"
            STOPPED=1
        fi
        rm -f "$pid_file"
    fi
done

# Clean up current config tracker and temporary files
rm -f current-config.txt
if [ -f "temp-config.txt" ]; then
    TEMP_CONFIG=$(cat temp-config.txt)
    rm -f "$TEMP_CONFIG"
    rm -f temp-config.txt
fi

if [ $STOPPED -eq 1 ]; then
    echo "✅ All services stopped successfully!"
else
    echo "ℹ️  No running services found"
fi