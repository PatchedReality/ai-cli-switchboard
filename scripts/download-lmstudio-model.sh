#!/bin/bash
# Download Model Script for LM Studio

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-utils.sh"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if model parameter provided
if [ -z "$1" ]; then
    error "No model specified\\n\\nUsage: $0 <model-name>\\n\\nExamples:\\n  $0 lmstudio-community/Llama-3-Groq-8B-Tool-Use-GGUF\\n  $0 meta-llama/Llama-3.1-8B-Instruct\\n  $0 llama-3.2-3b-instruct\\n\\n💡 The script will automatically select recommended quantization"
fi

MODEL_NAME="$1"

# Check if LM Studio CLI is available
LMS_PATH="$HOME/.lmstudio/bin/lms"
if [ ! -f "$LMS_PATH" ]; then
    error "LM Studio CLI not found at $LMS_PATH\\nPlease install LM Studio and run it at least once to set up the CLI\\nDownload from: https://lmstudio.ai/"
fi

# Make lms executable if needed
chmod +x "$LMS_PATH"

echo "📥 Downloading model: $MODEL_NAME"
echo "🔧 Using recommended quantization settings"
echo ""

# Download model with -y flag for automatic selection
"$LMS_PATH" get -y "$MODEL_NAME"

DOWNLOAD_STATUS=$?

echo ""
if [ $DOWNLOAD_STATUS -eq 0 ]; then
    echo "✅ Successfully downloaded: $MODEL_NAME"
    echo ""
    echo "📋 Available models:"
    "$LMS_PATH" ls
    echo ""
    echo "💡 Model ready to use with LM Studio configurations"
else
    error "Download failed for: $MODEL_NAME\\n\\n💡 Available models you can search for:\\n   Run: lms get <search-term> (interactive mode)"
fi