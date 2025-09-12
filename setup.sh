#!/bin/bash
# Setup Script for Claude Multi-Model AI Assistant

set -e

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

if [[ "$PYTHON_VERSION" < "3.10" ]]; then
    echo "⚠️  Python 3.10+ recommended. Found: $PYTHON_VERSION"
    echo "   Current setup may work but upgrade recommended"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled. Upgrade Python and try again."
        exit 1
    fi
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
    echo "   📥 Installing LiteLLM..."
    # Try multiple installation strategies
    if pip3 install 'litellm[proxy]' --user --upgrade --break-system-packages 2>/dev/null; then
        echo "   ✅ LiteLLM installed successfully"
    elif pip3 install litellm --user --upgrade --break-system-packages 2>/dev/null; then
        echo "   ✅ LiteLLM core installed successfully (proxy features may be limited)"
    elif pip3 install 'litellm==1.50.0' --user --break-system-packages 2>/dev/null; then
        echo "   ✅ LiteLLM installed successfully (pinned version)"
    elif command -v conda >/dev/null 2>&1 && conda install -c conda-forge litellm -y 2>/dev/null; then
        echo "   ✅ LiteLLM installed via conda"
    else
        echo "   ⚠️  LiteLLM installation failed - trying alternative approaches..."
        if pip3 install --user --break-system-packages --no-deps litellm 2>/dev/null; then
            echo "   ✅ LiteLLM core installed - proxy features may be limited"
            echo "   💡 Try installing proxy dependencies manually if needed:"
            echo "       pip3 install --user --break-system-packages pydantic fastapi uvicorn"
        else
            echo "   ⚠️  All installation methods failed"
            echo "   💡 Try manual installation: pip3 install --user --break-system-packages litellm"
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
        echo "   📥 Installing MLX..."
        # Try multiple installation strategies for MLX
        if arch | grep -q arm64; then
            echo "   📥 Installing MLX framework for Apple Silicon..."
            # MLX is available on PyPI - try direct installation
            if pip3 install mlx --user --break-system-packages 2>/dev/null; then
                echo "   ✅ MLX framework installed from PyPI"
                # Now install mlx-lm
                if pip3 install mlx-lm --user --break-system-packages 2>/dev/null; then
                    echo "   ✅ MLX-LM installed successfully - local models supported"
                else
                    echo "   ⚠️  MLX-LM installation failed, trying without dependencies..."
                    if pip3 install --user --break-system-packages --no-deps mlx-lm 2>/dev/null; then
                        echo "   ✅ MLX-LM installed (some dependencies may be missing)"
                        echo "   💡 Try: pip3 install --user --break-system-packages numpy transformers torch huggingface-hub"
                    fi
                fi
            else
                echo "   ⚠️  MLX framework installation failed, checking requirements..."
                echo "   💡 MLX requires:"
                echo "       - macOS >= 13.5 (recommended: macOS 14 Sonoma)"
                echo "       - Apple Silicon Mac (M-series chip)"
                echo "       - Python 3.9-3.12 (Python 3.12 recommended)"
                echo "   💡 Try manual installation: pip3 install --user --break-system-packages mlx"
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