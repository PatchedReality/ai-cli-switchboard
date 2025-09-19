#!/bin/bash
# Setup Script for Claude Multi-Model AI Assistant

set -e

# Function to check if pip supports --break-system-packages flag
supports_break_system_packages() {
    local pip_version=$(pip3 --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    if [ -z "$pip_version" ]; then
        return 1
    fi

    # Compare version - need pip >= 23.0.1
    local major=$(echo "$pip_version" | cut -d'.' -f1)
    local minor=$(echo "$pip_version" | cut -d'.' -f2)
    local patch=$(echo "$pip_version" | cut -d'.' -f3)

    if [ "$major" -gt 23 ]; then
        return 0
    elif [ "$major" -eq 23 ] && [ "$minor" -gt 0 ]; then
        return 0
    elif [ "$major" -eq 23 ] && [ "$minor" -eq 0 ] && [ "$patch" -ge 1 ]; then
        return 0
    else
        return 1
    fi
}

# Function to install package with appropriate pip flags
install_with_pip() {
    local package="$1"
    local description="$2"

    echo "   📥 Installing $description..."

    if supports_break_system_packages; then
        if pip3 install "$package" --user --upgrade --break-system-packages; then
            echo "   ✅ $description installed successfully"
            return 0
        else
            echo "   ❌ Failed to install $description with --break-system-packages"
            return 1
        fi
    else
        echo "   💡 Using --user flag (older pip version detected)"
        if pip3 install "$package" --user --upgrade; then
            echo "   ✅ $description installed successfully"
            return 0
        else
            echo "   ❌ Failed to install $description"
            return 1
        fi
    fi
}

echo "🚀 Setting up Claude Multi-Model AI Assistant..."
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  Warning: This setup is optimized for macOS with Apple Silicon"
    echo "   Remote models will work on any system, but local models require macOS + MLX"
    echo ""
fi

# Check Python version
PYTHON_VERSION=$(python3 --version 2>/dev/null | cut -d' ' -f2 | cut -d'.' -f1-2)
PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1-2)

# Check MLX compatibility for local models (Python 3.9+)
MLX_COMPATIBLE=false
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)
if [[ "$PYTHON_MAJOR" -eq 3 ]] && [[ "$PYTHON_MINOR" -ge 9 ]]; then
    MLX_COMPATIBLE=true
fi

if [[ "$PYTHON_VERSION" < "3.9" ]]; then
    echo "❌ Python 3.9+ required. Found: $PYTHON_VERSION"
    echo "   MLX requires Python 3.9+ and LiteLLM requires Python 3.8+"
    echo "   Please upgrade Python and try again."
    echo "   Recommended: brew install python@3.13"
    exit 1
elif [[ "$PYTHON_VERSION" < "3.10" ]]; then
    echo "⚠️  Python 3.9 detected. Supported but 3.10+ recommended."
    echo "   Found: $PYTHON_VERSION"
    echo "   Note: Some pip features may be limited with older Python versions"
    echo ""
elif [[ "$MLX_COMPATIBLE" == false ]]; then
    echo "⚠️  Python $PYTHON_VERSION detected - MLX local models not supported"
    echo "   MLX requires Python 3.9+ with native ARM architecture"
    echo "   Remote models will work fine, local models will be disabled"
    echo ""
    read -p "Continue with remote models only? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled. Install a compatible Python version for full MLX support:"
        echo "   brew install python@3.13"
        echo "   export PATH=\"/opt/homebrew/opt/python@3.13/libexec/bin:\$PATH\""
        exit 1
    fi
fi

echo "✅ Python version: $PYTHON_VERSION"

# Install LiteLLM
echo "📦 Installing LiteLLM (required for all models)..."
if python3 -c "import litellm" 2>/dev/null; then
    echo "   ✅ LiteLLM already installed"
    LITELLM_VERSION=$(python3 -c "import litellm._version; print(litellm._version.version)" 2>/dev/null || echo "unknown")
    echo "   📄 Version: $LITELLM_VERSION"
else
    # Try multiple installation strategies
    if install_with_pip 'litellm[proxy]' "LiteLLM with proxy support"; then
        true  # Success
    elif install_with_pip 'litellm' "LiteLLM core"; then
        echo "   💡 Proxy features may be limited without [proxy] extra"
    elif command -v conda >/dev/null 2>&1 && conda install -c conda-forge litellm -y 2>/dev/null; then
        echo "   ✅ LiteLLM installed via conda"
    else
        echo "   ⚠️  LiteLLM installation failed - trying fallback installation..."
        if supports_break_system_packages; then
            pip3 install --user --break-system-packages --no-deps litellm || echo "   ❌ Fallback installation failed"
        else
            pip3 install --user --no-deps litellm || echo "   ❌ Fallback installation failed"
        fi
        echo "   💡 If issues persist, try manual installation:"
        if supports_break_system_packages; then
            echo "       pip3 install --user --break-system-packages litellm"
        else
            echo "       pip3 install --user litellm"
        fi
    fi
fi

# Install MLX for local models (macOS only)
if [[ "$OSTYPE" == "darwin"* ]] && [[ "$MLX_COMPATIBLE" == true ]]; then
    echo "📦 Installing MLX (required for local models)..."
    if python3 -c "import mlx_lm" 2>/dev/null; then
        echo "   ✅ MLX already installed"
        MLX_VERSION=$(python3 -c "import mlx_lm; print(mlx_lm.__version__)" 2>/dev/null || echo "unknown")
        echo "   📄 Version: $MLX_VERSION"
    else
        # Try multiple installation strategies for MLX
        if arch | grep -q arm64; then
            echo "   📥 Installing MLX framework for Apple Silicon..."
            # Install MLX framework first
            if install_with_pip 'mlx' "MLX framework"; then
                # Now install mlx-lm
                if install_with_pip 'mlx-lm' "MLX-LM"; then
                    echo "   ✅ MLX installation complete - local models supported"
                else
                    echo "   ⚠️  MLX-LM installation failed, trying without dependencies..."
                    if supports_break_system_packages; then
                        pip3 install --user --break-system-packages --no-deps mlx-lm || echo "   ❌ MLX-LM fallback failed"
                    else
                        pip3 install --user --no-deps mlx-lm || echo "   ❌ MLX-LM fallback failed"
                    fi
                    echo "   💡 Some dependencies may be missing. Try installing manually:"
                    if supports_break_system_packages; then
                        echo "       pip3 install --user --break-system-packages numpy transformers torch huggingface-hub"
                    else
                        echo "       pip3 install --user numpy transformers torch huggingface-hub"
                    fi
                fi
            else
                echo "   ⚠️  MLX framework installation failed, checking requirements..."
                echo "   💡 MLX requires:"
                echo "       - macOS >= 13.5 (recommended: macOS 14 Sonoma)"
                echo "       - Apple Silicon Mac (M-series chip)"
                echo "       - Python 3.9+ (Python 3.10+ recommended)"
                echo "   💡 Try manual installation:"
                if supports_break_system_packages; then
                    echo "       pip3 install --user --break-system-packages mlx mlx-lm"
                else
                    echo "       pip3 install --user mlx mlx-lm"
                fi
            fi
        else
            echo "   ⚠️  MLX requires Apple Silicon Mac (arm64 architecture)"
            echo "   💡 Current architecture: $(arch)"
            echo "   💡 Local models will not work on this system"
        fi
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "⏭️  Skipping MLX installation (Python $PYTHON_VERSION not compatible)"
    echo "   💡 MLX requires Python 3.9+, local models disabled"
else
    echo "⏭️  Skipping MLX installation (not on macOS)"
fi

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x scripts/*.sh

# Check if Claude Code is installed
if command -v claude >/dev/null 2>&1; then
    echo "✅ Claude Code found"
    CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1 || echo "version unknown")
    echo "   📄 $CLAUDE_VERSION"
else
    echo "⚠️  Claude Code not found"
    echo "   📥 Install from: https://github.com/anthropics/claude-code"
    echo "   💡 Or run: curl -fsSL https://claude.ai/install.sh | sh"
    echo ""
    read -p "Would you like to install Claude Code now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   📥 Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | sh
        if command -v claude >/dev/null 2>&1; then
            echo "   ✅ Claude Code installed successfully"
        else
            echo "   ⚠️  Claude Code installation may need to be completed manually"
        fi
    fi
fi

# Configure Codex CLI profiles if Codex is installed
if command -v codex >/dev/null 2>&1; then
    echo "🤖 Configuring Codex CLI profiles..."
    scripts/setup-codex.sh
else
    echo "ℹ️  Codex CLI not detected. Install with 'npm install -g @openai/codex' or 'brew install codex'"
    echo "   Run ./scripts/setup-codex.sh after installing to generate profiles."
fi

# Check if critical dependencies were installed successfully
LITELLM_INSTALLED=false
MLX_INSTALLED=false

if python3 -c "import litellm" 2>/dev/null; then
    LITELLM_INSTALLED=true
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    if python3 -c "import mlx_lm" 2>/dev/null; then
        MLX_INSTALLED=true
    fi
else
    MLX_INSTALLED=true  # Not needed on non-macOS
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Create .env file with your API keys (see README)"
echo "2. Run: ./scripts/setup-aliases.sh (optional convenience aliases)"
echo "3. Start a model: ./scripts/start-remote.sh configs/remote-deepseek.yaml"
echo "4. Use Claude Code: claudel (if aliases set up) or ANTHROPIC_BASE_URL=http://localhost:18080 claude"
echo ""
echo "📖 See README.md for detailed usage instructions"
