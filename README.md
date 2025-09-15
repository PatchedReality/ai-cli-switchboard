# Claude + Multi-Model AI Assistant

Flexible AI coding assistant with support for local and remote models via LiteLLM proxy. Use any model with the same Claude Code interface and tools.

## 📋 Prerequisites

### System Requirements
- **macOS** with Apple Silicon (M1/M2/M3/M4) for local MLX models
- **Python 3.10+** (Python 3.12 recommended for full MLX support)
- **Claude Code** - Install from [Anthropic's official CLI](https://github.com/anthropics/claude-code)
- **LM Studio** (optional) - For better local model management and tool calling

### Quick Setup

```bash
# Run the setup script (installs dependencies)
./setup.sh
```

**Manual installation:**
```bash
# Install LiteLLM (required for all models)
pip3 install 'litellm[proxy]'

# Install MLX (required for MLX local models only)
pip3 install mlx-lm

# Optional: Install LM Studio for enhanced local model support
# Download from: https://lmstudio.ai/

# Set Python path for user installs (improves command availability)
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)
export PATH="$HOME/Library/Python/$PYTHON_VERSION/bin:$PATH"
```

## 🚀 Quick Start

### 1. Setup Environment Variables

Create a `.env` file for API keys:
```bash
# Required for remote models
DEEPSEEK_API_KEY=your_deepseek_key
GEMINI_API_KEY=your_gemini_key  
OPENROUTER_API_KEY=your_openrouter_key
```

### 2. Choose and Start a Model

```bash
# List available configurations
ls configs/

# Remote models (require API keys)
./scripts/start-remote.sh configs/remote-deepseek.yaml
./scripts/start-remote.sh configs/remote-gemini-flash.yaml
./scripts/start-remote.sh configs/remote-gemini-pro.yaml
./scripts/start-remote.sh configs/remote-glm-4.5-air-zai.yaml

# Local models via MLX (no API keys needed, requires model download)
./scripts/start-local.sh configs/local-glm-9b.yaml
./scripts/start-local.sh configs/local-glm-32b.yaml
./scripts/start-local.sh configs/local-deepseek-v2.5.yaml
./scripts/start-local.sh configs/local-fuseo1.yaml
./scripts/start-local.sh configs/local-gemma-2b-coder.yaml

# Local models via LM Studio (better tool calling support)
./scripts/start-lmstudio.sh configs/lmstudio-llama-groq-tool.yaml
./scripts/start-lmstudio.sh configs/lmstudio-gemma-7b.yaml
./scripts/start-lmstudio.sh configs/lmstudio-gemma-2b-coder.yaml
```

### 3. Use with Claude Code

```bash
# Option 1: Set environment variable each time
ANTHROPIC_BASE_URL=http://localhost:18080 ANTHROPIC_API_KEY=dummy-key claude

# Option 2: Use the claudel alias (after setting up aliases)
claudel
```

**Note:** When starting a `claudel` session, you may see this authentication warning:
```
⚠ Auth conflict: Both a token (claude.ai) and an API key (ANTHROPIC_API_KEY) are set.
   This may lead to unexpected behavior.
```
This warning can be safely ignored when using local models via the proxy. The `claudel` alias is designed to work with this configuration.

## 🎛️ Server Management

```bash
./scripts/start-remote.sh <config>  # Start remote model
./scripts/start-local.sh <config>   # Start local model  
./scripts/stop.sh                   # Stop all services
./scripts/status.sh                 # Check server status
```

## ⚡ Convenient Aliases

Set up shortcuts for quick model switching:
```bash
./scripts/setup-aliases.sh   # Creates ai-aliases.sh
source ai-aliases.sh         # Load aliases

# Now use shortcuts like:
claude-remote-deepseek         # Start DeepSeek-R1
claude-local-glm-9b           # Start local GLM-9B
claude-local-deepseek         # Start local DeepSeek-V2.5
claude-local-fuseo1           # Start local FuseO1
claude-local-gemma-2b         # Start local Gemma 2B
claude-lmstudio-llama-groq    # Start Llama 3 Groq via LM Studio
claude-lmstudio-gemma-7b      # Start CodeGemma 7B via LM Studio
claude-stop                   # Stop services
claude-status                 # Check status
claude-models                 # Show all available commands
claudel                       # Run Claude Code with local proxy
```

## 📊 Available Models

### Remote Models (require API keys)
- **DeepSeek-R1**: Advanced reasoning model ($2.19/1M output tokens)
- **Gemini 2.5 Flash**: Google's latest (requires billing setup)
- **GLM-4.5-Air**: Via OpenRouter (~$0.5-2/1M tokens)

### Local Models (no API keys, requires MLX)
- **GLM-4-9B**: Smaller, faster model (~2GB memory)
- **GLM-4-32B**: Larger, more capable model (~8GB memory)
- **DeepSeek-V2.5**: Advanced reasoning model (~25-30GB memory)
- **FuseO1**: DeepSeek+Qwen Coder fusion (~6-8GB memory)
- **Gemma 2B Coder**: Ultra-fast coding model (~1-2GB memory)

### LM Studio Models (better tool calling support)
- **Gemma 2B Coder**: Ultra-fast coding via LM Studio (~1-2GB memory)
- **CodeGemma 7B**: Enhanced coding model via LM Studio (~5GB memory)
- **Llama 3 Groq 8B Tool Use**: Specialized for function calling (~5GB memory, 89.06% BFCL)

## 🔧 Technical Details

- **Proxy**: LiteLLM on port 18080
- **Local Engine**: MLX for Apple Silicon optimization
- **API Compatible**: Works seamlessly with Claude Code interface
- **Environment**: Automatic .env loading for API keys
- **Config System**: YAML-based model configurations with variable substitution

## 🆘 Troubleshooting

### Server Issues
- **Won't start**: Check `litellm-proxy.log` for errors
- **Port conflict**: Another service using port 18080
- **API key errors**: Verify keys in `.env` file

### Local Models
- **Model not found**: Models download automatically on first use
- **Memory issues**: Use GLM-9B for lower memory usage
- **MLX errors**: Ensure you're on Apple Silicon with MLX installed

### Remote Models
- **Authentication failed**: Check API keys in `.env`
- **Rate limiting**: Most services have usage limits
- **Billing required**: Gemini models require billing setup

### Setup Issues
- **`litellm` command not found**: Run `pip3 install 'litellm[proxy]' --user` and add the appropriate Python user bin directory to PATH (e.g., `export PATH="$HOME/Library/Python/$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)/bin:$PATH")`
- **`claude` command not found**: Install Claude Code from https://github.com/anthropics/claude-code
- **Python version**: Requires Python 3.10+ for general use, 3.9-3.13 for MLX local models
- **MLX installation**: Requires Apple Silicon Mac with Python 3.9-3.13

### Python Version Management
MLX works with Python 3.9-3.13. If you need a specific version:
```bash
# Install specific Python version via Homebrew (if needed)
brew install python@3.13

# Make it the default python3 (add to ~/.zshrc or ~/.bashrc)
export PATH="/usr/local/opt/python@3.12/libexec/bin:$PATH"

# Verify the version
python3 --version
```

## 📁 Project Structure

```
configs/           # Model configuration files
├── local-*.yaml     # Local MLX models
├── lmstudio-*.yaml  # LM Studio models
└── remote-*.yaml    # Remote API models

scripts/           # Management scripts
├── start-remote.sh    # Start remote models
├── start-local.sh     # Start local models
├── start-lmstudio.sh  # Start LM Studio models
├── download-model.sh  # Download models cleanly
├── stop.sh           # Stop all services
├── status.sh         # Check status
└── setup-aliases.sh  # Create convenience aliases

.env              # API keys (create this)
ai-aliases.sh     # Generated aliases (after setup)
```

---
*Note: The `claude` command by default connects to Anthropic's servers. To use your local models, either set the environment variables manually or use the `claudel` alias provided in the setup.*