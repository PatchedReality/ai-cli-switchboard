#!/bin/bash
# Setup Convenient Aliases for Model Switching

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔧 Setting up AI model aliases..."
echo ""

# Create alias script
cat > "$PROJECT_DIR/ai-aliases.sh" << 'EOF'
#!/bin/bash
# AI Model Aliases - Source this file or add to your .bashrc/.zshrc

# Get the directory of this script
AI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Local Models
alias claude-local-glm-9b="$AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-glm-9b.yaml"
alias claude-local-glm-32b="$AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-glm-32b.yaml"
alias claude-local-deepseek="$AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-deepseek-v2.5.yaml"
alias claude-local-fuseo1="$AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-fuseo1.yaml"
alias claude-local-gemma-2b="$AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-gemma-2b-coder.yaml"

# Remote Models  
alias claude-remote-glm="$AI_DIR/scripts/claude-zai.sh"
alias claude-remote-glm-air="$AI_DIR/scripts/claude-zai.sh --air"
alias claude-remote-deepseek="$AI_DIR/scripts/start-remote.sh $AI_DIR/configs/remote-deepseek.yaml"
alias claude-remote-gemini-flash="$AI_DIR/scripts/start-remote.sh $AI_DIR/configs/remote-gemini-flash.yaml"
alias claude-remote-gemini-pro="$AI_DIR/scripts/start-remote.sh $AI_DIR/configs/remote-gemini-pro.yaml"
alias claude-remote-gemini="$AI_DIR/scripts/start-remote.sh $AI_DIR/configs/remote-gemini-flash.yaml"

# Universal commands
alias claude-stop="$AI_DIR/scripts/stop.sh"
alias claude-status="$AI_DIR/scripts/status.sh"

# Claude Code with local proxy
alias claudel="ANTHROPIC_BASE_URL=http://localhost:18080 ANTHROPIC_API_KEY=dummy-key claude"

# Note: All start commands automatically stop existing services first
# So no separate switch commands are needed

# Show available models
alias claude-models="echo 'Available Models:'; echo '  Local: claude-local-glm-9b, claude-local-glm-32b, claude-local-deepseek, claude-local-fuseo1, claude-local-gemma-2b'; echo '  Remote: claude-remote-glm, claude-remote-glm-air, claude-remote-deepseek, claude-remote-gemini-flash, claude-remote-gemini-pro'"

echo "🤖 AI model aliases loaded!"
echo "Usage: claude-models (to see all commands)"
echo "Use 'claudel' to run Claude Code with your local models"
EOF

chmod +x "$PROJECT_DIR/ai-aliases.sh"

echo "✅ Aliases created!"
echo ""
echo "📋 Available Commands:"
echo "   🏠 Local Models:"
echo "      claude-local-glm-9b     - GLM-4-9B (2GB, fast)"
echo "      claude-local-glm-32b    - GLM-4-32B (8GB, better)"  
echo "      claude-local-deepseek - DeepSeek-V2.5 (25-30GB, reasoning)
      claude-local-fuseo1 - FuseO1 DeepSeek+Qwen Coder (6-8GB, coding+tools)
      claude-local-gemma-2b - Gemma 2B Coder (1-2GB, fast coding)"
echo ""
echo ""
echo "   ☁️  Remote Models:"
echo "      claude-remote-glm   - GLM-4.5 (Z.AI)"
echo "      claude-remote-glm-air - GLM-4.5-Air (Z.AI)"
echo "      claude-remote-deepseek - DeepSeek-R1 (platform.deepseek.com)"
echo "      claude-remote-gemini-flash - Gemini 2.5 Flash (ai.google.dev)"
echo "      claude-remote-gemini-pro - Gemini 2.5 Pro (ai.google.dev)"
echo "      claude-remote-gemini - Gemini Flash (default, ai.google.dev)"
echo ""
echo "   ℹ️  Note:"
echo "      All start commands automatically stop existing services first"
echo ""
echo "   🎛️  Control:"
echo "      claude-stop         - Stop all services"
echo "      claude-status       - Check what's running"
echo "      claude-models       - Show this help"
echo ""
echo "   🖥️  Claude Code:"
echo "      claudel             - Run Claude Code with local proxy"
echo ""
echo "🔧 To activate aliases:"
echo "   source ai-aliases.sh"
echo ""
echo "🔧 To make permanent, add this to your ~/.bashrc or ~/.zshrc:"
echo "   source \"$PROJECT_DIR/ai-aliases.sh\""