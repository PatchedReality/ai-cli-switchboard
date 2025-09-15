#!/bin/bash
# Download Model Script for LM Studio

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if model parameter provided
if [ -z "$1" ]; then
    echo "❌ Error: No model specified"
    echo ""
    echo "Usage: $0 <model-name>"
    echo ""
    echo "Examples:"
    echo "  $0 lmstudio-community/Llama-3-Groq-8B-Tool-Use-GGUF"
    echo "  $0 meta-llama/Llama-3.1-8B-Instruct"
    echo "  $0 llama-3.2-3b-instruct"
    echo ""
    echo "💡 The script will automatically select recommended quantization"
    exit 1
fi

MODEL_NAME="$1"

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
    echo "❌ Download failed for: $MODEL_NAME"
    echo ""
    echo "💡 Available models you can search for:"
    echo "   Run: lms get <search-term> (interactive mode)"
    exit 1
fi