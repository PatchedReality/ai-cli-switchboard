#!/bin/bash
# Universal Local Model Starter with MLX + LiteLLM

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-utils.sh"

# Trap Ctrl-C and cleanup
cleanup_on_interrupt() {
    echo ""
    echo "🛑 Interrupted by user, cleaning up..."

    # Kill MLX server if PID file exists
    if [ -f "mlx-server.pid" ]; then
        MLX_PID=$(cat mlx-server.pid)
        if kill -0 "$MLX_PID" 2>/dev/null; then
            echo "   Stopping MLX server (PID: $MLX_PID)..."
            pkill -P "$MLX_PID" 2>/dev/null || true
            kill "$MLX_PID" 2>/dev/null || true
        fi
        rm -f mlx-server.pid
    fi

    # Kill LiteLLM proxy if PID file exists
    if [ -f "litellm-proxy.pid" ]; then
        PROXY_PID=$(cat litellm-proxy.pid)
        if kill -0 "$PROXY_PID" 2>/dev/null; then
            echo "   Stopping LiteLLM proxy (PID: $PROXY_PID)..."
            kill "$PROXY_PID" 2>/dev/null || true
        fi
        rm -f litellm-proxy.pid
    fi

    echo "✅ Cleanup complete"
    exit 130
}

trap cleanup_on_interrupt SIGINT SIGTERM

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

# Check if model exists locally and is fully downloaded
echo "🔍 Checking model availability: $MODEL"
MODEL_STATUS=$(python3 -c "
import os
import json
import glob
try:
    cache_dir = os.path.expanduser('~/.cache/huggingface/hub')
    if not os.path.exists(cache_dir):
        print('not_found')
        exit()

    model_name = 'models--' + '$MODEL'.replace('/', '--').lower()
    model_dir = None

    # Find the model directory (case-insensitive)
    for d in os.listdir(cache_dir):
        if d.lower() == model_name and os.path.isdir(os.path.join(cache_dir, d)):
            model_dir = os.path.join(cache_dir, d)
            break

    if not model_dir:
        print('not_found')
        exit()

    # Check for critical files in snapshots
    snapshots_dir = os.path.join(model_dir, 'snapshots')
    if not os.path.exists(snapshots_dir):
        print('incomplete')
        exit()

    # Get the latest snapshot
    snapshots = [d for d in os.listdir(snapshots_dir) if os.path.isdir(os.path.join(snapshots_dir, d))]
    if not snapshots:
        print('incomplete')
        exit()

    latest_snapshot = os.path.join(snapshots_dir, snapshots[0])

    # Check if config.json is valid JSON (not truncated)
    config_path = os.path.join(latest_snapshot, 'config.json')
    if not os.path.exists(config_path):
        print('incomplete')
        exit()

    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
    except:
        print('incomplete')
        exit()

    # Check for sharded models - verify all shards are present
    index_path = os.path.join(latest_snapshot, 'model.safetensors.index.json')
    if os.path.exists(index_path):
        # Sharded model - check index file is valid and all shards exist
        try:
            with open(index_path, 'r') as f:
                index = json.load(f)

            # Get expected shard files from index
            if 'weight_map' in index:
                expected_shards = set(index['weight_map'].values())

                # Check all shards exist
                for shard in expected_shards:
                    shard_path = os.path.join(latest_snapshot, shard)
                    if not os.path.exists(shard_path) or os.path.getsize(shard_path) == 0:
                        print('incomplete')
                        exit()
        except Exception as e:
            # Invalid or empty index file
            print('incomplete')
            exit()
    else:
        # Single file model - check for model file
        model_files = ['model.safetensors', 'pytorch_model.bin', 'model.bin']
        has_model = any(os.path.exists(os.path.join(latest_snapshot, f)) and
                       os.path.getsize(os.path.join(latest_snapshot, f)) > 0
                       for f in model_files)

        if not has_model:
            print('incomplete')
            exit()

    # Check for tokenizer files
    tokenizer_files = ['tokenizer.json', 'tokenizer.model']
    has_tokenizer = any(os.path.exists(os.path.join(latest_snapshot, f))
                       for f in tokenizer_files)

    if not has_tokenizer:
        print('incomplete')
        exit()

    print('complete')
except Exception as e:
    print('error')
")

if [ "$MODEL_STATUS" = "complete" ]; then
    echo "✅ Model found in local cache and fully downloaded"
    echo "📡 Starting MLX server on port $MLX_PORT..."

    # Start MLX server in background
    nohup python3 -c "
from mlx_lm.server import main
import sys
sys.argv = ['mlx_lm.server', '--model', '$MODEL', '--port', '$MLX_PORT']
main()
" > "mlx-server.log" 2>&1 &
    MLX_PID=$!

    # Save PID immediately so it can be stopped if interrupted
    echo "$MLX_PID" > mlx-server.pid

    # Wait for MLX server to be ready and model loaded
    echo "⏳ Waiting for model to load into memory..."

    # First wait for server to start responding
    while true; do
        if curl -s http://localhost:$MLX_PORT/v1/models > /dev/null 2>&1; then
            break
        fi
        sleep 2
    done

    # Now test that model can actually handle requests (means model is loaded)
    echo "🧪 Testing model is fully loaded and functional..."
    while true; do
        if curl -s -X POST http://localhost:$MLX_PORT/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d '{"model": "'$MODEL'", "messages": [{"role": "user", "content": "test"}], "max_tokens": 1}' \
            2>/dev/null | grep -q '"choices"'; then
            echo "✅ Model is loaded and ready!"
            break
        fi
        sleep 5
    done

elif [ "$MODEL_STATUS" = "incomplete" ]; then
    echo "⚠️  Model found but appears incomplete (partial download detected)"
    echo "🗑️  Cleaning up incomplete model cache..."

    # Remove the incomplete model directory
    python3 -c "
import os
import shutil
cache_dir = os.path.expanduser('~/.cache/huggingface/hub')
model_name = 'models--' + '$MODEL'.replace('/', '--').lower()
for d in os.listdir(cache_dir):
    if d.lower() == model_name:
        model_path = os.path.join(cache_dir, d)
        print(f'Removing incomplete model at: {model_path}')
        shutil.rmtree(model_path)
        break
"

    echo "📦 Re-downloading model from scratch..."
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

    # Save PID immediately so it can be stopped if interrupted
    echo "$MLX_PID" > mlx-server.pid

    # Wait for server to be responding and model to be fully loaded
    echo ""
    echo "⏳ Waiting for server to be ready (downloading model if needed)..."
    echo "   This may take several minutes for large models..."

    # First wait for server to start responding
    while true; do
        if curl -s http://localhost:$MLX_PORT/v1/models > /dev/null 2>&1; then
            break
        fi
        sleep 5
    done

    # Now test that model can actually handle requests (means download is complete)
    echo "🧪 Testing model is fully loaded and functional..."
    while true; do
        if curl -s -X POST http://localhost:$MLX_PORT/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d '{"model": "'$MODEL'", "messages": [{"role": "user", "content": "test"}], "max_tokens": 1}' \
            2>/dev/null | grep -q '"choices"'; then
            echo "✅ MLX server is ready and model is fully loaded!"
            break
        fi
        sleep 10
    done

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

    # Save PID immediately so it can be stopped if interrupted
    echo "$MLX_PID" > mlx-server.pid

    # Wait for server to be responding and model to be fully loaded
    echo ""
    echo "⏳ Waiting for server to be ready (downloading model if needed)..."
    echo "   This may take several minutes for large models..."

    # First wait for server to start responding
    while true; do
        if curl -s http://localhost:$MLX_PORT/v1/models > /dev/null 2>&1; then
            break
        fi
        sleep 5
    done

    # Now test that model can actually handle requests (means download is complete)
    echo "🧪 Testing model is fully loaded and functional..."
    while true; do
        if curl -s -X POST http://localhost:$MLX_PORT/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d '{"model": "'$MODEL'", "messages": [{"role": "user", "content": "test"}], "max_tokens": 1}' \
            2>/dev/null | grep -q '"choices"'; then
            echo "✅ MLX server is ready and model is fully loaded!"
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

# Save PIDs and config (MLX PID already saved earlier to handle Ctrl-C)
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