#!/bin/bash
# Z.AI Direct Claude Integration

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-utils.sh"

# Check if model variant is specified
MODEL_VARIANT=""
if [[ "$1" == "--air" ]]; then
    MODEL_VARIANT="air"
    shift # Remove --air from arguments passed to claude
fi

# Stop any running local services first
log_with_time "🛑 Stopping local services (switching to Z.AI direct)..."
stop_all_services >/dev/null 2>&1 || true

# Load environment variables
load_env_file

# Check if ZAI_API_KEY is set
if [ -z "$ZAI_API_KEY" ]; then
    error "ZAI_API_KEY not found in .env file"
fi

# Show what we're doing
if [ "$MODEL_VARIANT" = "air" ]; then
    log_with_time "🚀 Starting Claude Code with GLM-4.5-Air via Z.AI direct connection"
else
    log_with_time "🚀 Starting Claude Code with GLM-4.5 via Z.AI direct connection"
fi

# Set Z.AI environment and run Claude
export ANTHROPIC_BASE_URL="https://open.bigmodel.cn/api/anthropic"
export ANTHROPIC_API_KEY="$ZAI_API_KEY"

log_with_time "🌐 Connecting to Z.AI at https://open.bigmodel.cn/api/anthropic"

exec claude "$@"