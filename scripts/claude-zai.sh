#!/bin/bash
# Z.AI Direct Claude Integration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if model variant is specified
MODEL_VARIANT=""
if [[ "$1" == "--air" ]]; then
    MODEL_VARIANT="air"
    shift # Remove --air from arguments passed to claude
fi

# Load environment variables safely
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
else
    echo "❌ .env file not found"
    exit 1
fi

# Check if ZAI_API_KEY is set
if [ -z "$ZAI_API_KEY" ]; then
    echo "❌ ZAI_API_KEY not found in .env file"
    exit 1
fi

# Set Z.AI environment and run Claude
export ANTHROPIC_BASE_URL="https://open.bigmodel.cn/api/anthropic"
export ANTHROPIC_API_KEY="$ZAI_API_KEY"

exec claude "$@"