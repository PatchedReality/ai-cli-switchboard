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
alias claude-local-9b="$AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-glm-9b.yaml"
alias claude-local-32b="$AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-glm-32b.yaml"
alias claude-local-deepseek="$AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-deepseek-v2.5.yaml"

# Remote Models  
alias claude-remote-glm="$AI_DIR/scripts/start-remote.sh $AI_DIR/configs/remote-glm-4.5-air.yaml"
alias claude-remote-deepseek="$AI_DIR/scripts/start-remote.sh $AI_DIR/configs/remote-deepseek.yaml"
alias claude-remote-gemini="$AI_DIR/scripts/start-remote.sh $AI_DIR/configs/remote-gemini.yaml"

# Universal commands
alias claude-stop="$AI_DIR/scripts/stop.sh"
alias claude-status="$AI_DIR/scripts/status.sh"

# Claude Code with local proxy
alias claudel="ANTHROPIC_BASE_URL=http://localhost:18080 ANTHROPIC_API_KEY=dummy-key claude"

# Quick switchers (stop current, start new)
alias claude-switch-9b="$AI_DIR/scripts/stop.sh && $AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-glm-9b.yaml"
alias claude-switch-32b="$AI_DIR/scripts/stop.sh && $AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-glm-32b.yaml"
alias claude-switch-local-deepseek="$AI_DIR/scripts/stop.sh && $AI_DIR/scripts/start-local.sh $AI_DIR/configs/local-deepseek-v2.5.yaml"
alias claude-switch-glm="$AI_DIR/scripts/stop.sh && $AI_DIR/scripts/start-remote.sh $AI_DIR/configs/remote-glm-4.5-air.yaml"
alias claude-switch-deepseek="$AI_DIR/scripts/stop.sh && $AI_DIR/scripts/start-remote.sh $AI_DIR/configs/remote-deepseek.yaml"
alias claude-switch-gemini="$AI_DIR/scripts/stop.sh && $AI_DIR/scripts/start-remote.sh $AI_DIR/configs/remote-gemini.yaml"

# Show available models
alias claude-models="echo 'Available Models:'; echo '  Local: claude-local-9b, claude-local-32b, claude-local-deepseek'; echo '  Remote: claude-remote-glm, claude-remote-deepseek, claude-remote-gemini'; echo '  Quick Switch: claude-switch-[model]'; echo '  Control: claude-stop, claude-status'; echo '  Claude Code: claudel (connects to local proxy)'"

echo "🤖 AI model aliases loaded!"
echo "Usage: claude-models (to see all commands)"
echo "Use 'claudel' to run Claude Code with your local models"
EOF

chmod +x "$PROJECT_DIR/ai-aliases.sh"

echo "✅ Aliases created!"
echo ""
echo "📋 Available Commands:"
echo "   🏠 Local Models:"
echo "      claude-local-9b     - GLM-4-9B (2GB, fast)"
echo "      claude-local-32b    - GLM-4-32B (8GB, better)"  
echo "      claude-local-deepseek - DeepSeek-V2.5 (25-30GB, reasoning)"
echo ""
echo "   ☁️  Remote Models:"
echo "      claude-remote-glm   - GLM-4.5-Air (OpenRouter)"
echo "      claude-remote-deepseek - DeepSeek-R1 (PAID)"
echo "      claude-remote-gemini - Gemini 2.5 Pro (PAID)"
echo ""
echo "   🔄 Quick Switchers:"
echo "      claude-switch-[model] - Stop current, start new"
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