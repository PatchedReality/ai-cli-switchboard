# AI CLI Switchboard

A simple framework for using Claude Code or Codex CLI as the frontend to any cloud or local LLM on Apple Silicon. Connect locally via LiteLLM + MLX or LM Studio, or remotely via Z.AI, Gemini/Google AI Studio, DeepSeek, or OpenRouter.

## Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                    AI CLI SWITCHBOARD                             │
│              One Interface → Any LLM (Cloud or Local)             │
└───────────────────────────────────────────────────────────────────┘

            ┌─────────────┐          ┌─────────────┐
            │ Claude Code │          │ Codex CLI   │
            └──┬────────┬─┘          └──────┬──────┘
               │        │                   │
          ANTHROPIC_BASE_URL           Codex profiles
          + ANTHROPIC_API_KEY          (config.yaml)
               │        │                   │
               │        └───────────────────┘
               │                    │
   open.bigmodel.cn          localhost:18080
      (Claude only)                 │
               │                    ▼
               ▼              ┌──────────┐
         ┌──────────┐         │ LiteLLM  │
         │  Z.AI    │         │  Proxy   │
         │  Direct  │         │  :18080  │
         │ GLM-4.5  │         └────┬─────┘
         └──────────┘              │
                              ┌────┴────┬────────┐
                              │         │        │
                              ▼         ▼        ▼
                           ┌─────┐  ┌────────┐  ┌─────────┐
                           │ MLX │  │   LM   │  │ Remote  │
                           │18081│  │ Studio │  │  APIs   │
                           └──┬──┘  └───┬────┘  └────┬────┘
                              │         │            │
                              ▼         ▼            ▼
                           ┌─────┐  ┌────────┐  ┌─────────┐
                           │GLM9B│  │ Llama  │  │DeepSeek │
                           │GLM32│  │  Qwen  │  │ Gemini  │
                           └─────┘  └────────┘  └─────────┘
                            Apple     Better      Cloud
                           Silicon    Tools       APIs
```

## 📋 Prerequisites

### System Requirements
- **macOS** with Apple Silicon (M1/M2/M3/M4) for local MLX models
- **Python 3.10+**
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

# Remote models via LiteLLM (require API keys)
./scripts/start-remote.sh configs/remote-deepseek.yaml

# Remote models via Z.AI direct (require Z.AI API key)
./scripts/claude-zai.sh          # GLM-4.5

# Local models via MLX (no API keys needed, requires model download)
./scripts/start-local.sh configs/local-glm-9b.yaml

# Local models via LM Studio (better tool calling support)
./scripts/start-lmstudio.sh configs/lmstudio-llama-groq-tool.yaml

# See all available models
ls configs/
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

### 4. Use with Codex CLI

```bash
# Install Codex CLI if needed
npm install -g @openai/codex

# Step 1: Generate Codex profiles
./scripts/setup-codex.sh

# Step 2: Generate shell aliases (includes codex-* shortcuts)
./scripts/setup-aliases.sh
source ai-aliases.sh

# Now use Codex with any model (starts backend automatically)
codex-models                # List all available Codex profiles
codex-local-glm-9b          # Start GLM-9B backend + launch Codex
codex-lmstudio-llama-groq   # Start Llama Groq backend + launch Codex

# Pass Codex flags as usual
codex-local-glm-9b --sandbox danger-full-access
```

Codex profiles mirror the Claude aliases. Each `codex-*` helper first boots the corresponding configuration (calling `start-local.sh`, `start-lmstudio.sh`, or `start-remote.sh`) and then launches Codex pointed at the LiteLLM proxy (`http://localhost:18080/v1`). The helper also sets `LITELLM_API_KEY=${LITELLM_API_KEY:-dummy-key}` so it works out of the box; export a different key beforehand if your proxy requires one.

## 🎛️ Server Management

```bash
# Start models by type
./scripts/start-remote.sh <config>    # Start remote model via LiteLLM
./scripts/start-local.sh <config>     # Start local model via MLX
./scripts/start-lmstudio.sh <config>  # Start local model via LM Studio
./scripts/claude-zai.sh [--air]       # Start GLM model via Z.AI direct

# Universal management
./scripts/stop.sh                     # Stop all services
./scripts/status.sh                   # Check server status
```

## ⚡ Dynamic Alias System

The setup script now automatically generates aliases from config metadata - no manual updates needed when adding new models!

```bash
./scripts/setup-aliases.sh   # Creates ai-aliases.sh from configs
source ai-aliases.sh         # Load aliases

# Now use shortcuts like:
claude-remote-deepseek         # Start DeepSeek-R1 (example remote)
claude-local-glm-9b           # Start local GLM-9B (example local)
claude-lmstudio-llama-groq    # Start Llama 3 Groq via LM Studio (example)
claude-stop                   # Stop services
claude-status                 # Check status
claude-models                 # Show all available commands
claudel                       # Run Claude Code with local proxy
```

**🔧 How it works:**
- Each config file has an `alias_config` section with metadata
- `setup-aliases.sh` reads all configs and generates aliases automatically
- Adding new configs = new aliases automatically appear
- No more manual alias maintenance!

## 🏃 Runner Types

The system supports four different runner types, each optimized for specific model deployment scenarios:

### `local_mlx` - Local MLX Models
- **Engine**: MLX framework for Apple Silicon optimization
- **Memory usage**: Varies by model (1-30GB)
- **Requirements**: Apple Silicon Mac, MLX installed
- **Example**: GLM-4-9B
- **Best for**: Fast local inference on Apple Silicon

### `local_lmstudio` - Local LM Studio Models
- **Engine**: LM Studio with enhanced tool calling support
- **Memory usage**: Varies by model (1-8GB)
- **Requirements**: LM Studio installed, models downloaded via LM Studio
- **Example**: Llama 3 Groq Tool Use
- **Best for**: Models requiring better function calling capabilities

### `remote_litellm` - Remote API Models via LiteLLM
- **Engine**: LiteLLM proxy for API model abstraction
- **Requirements**: API keys, internet connection
- **Example**: DeepSeek-R1
- **Best for**: Access to state-of-the-art remote models

### `remote_zai` - Remote Z.AI Direct Connection
- **Engine**: Direct connection to Z.AI endpoints
- **Requirements**: Z.AI API key, no local proxy needed
- **Example**: GLM-4.5
- **Best for**: Direct access to GLM models without proxy overhead

## 📊 Available Models

The system supports 20+ models across four categories. Use `ls configs/` to see all available configurations.

### Remote Models (require API keys)
- **Example**: DeepSeek-R1 - Advanced reasoning model ($2.19/1M output tokens)
- See `configs/remote-*.yaml` for all remote options

### Local MLX Models (no API keys, requires MLX)
- **Example**: GLM-4-9B - Smaller, faster model (~2GB memory)
- See `configs/local-*.yaml` for all local options

### LM Studio Models (better tool calling support)
- **Example**: Llama 3 Groq 8B Tool Use - Specialized for function calling (~5GB memory, 89.06% BFCL)
- See `configs/lmstudio-*.yaml` for all LM Studio options

## 🔧 Adding New Models

To add a new model:

1. **Create a config file** in `configs/` following the naming pattern:
   - `remote-{name}.yaml` for remote models
   - `local-{name}.yaml` for MLX local models
   - `lmstudio-{name}.yaml` for LM Studio models

2. **Copy an existing config** as a template and modify:
   - Model name and settings
   - Runner type (`remote_litellm`, `local_mlx`, `local_lmstudio`)
   - Alias configuration for automatic alias generation

3. **Regenerate aliases**:
   ```bash
   ./scripts/setup-aliases.sh
   source ai-aliases.sh
   ```

4. **Your new model** will automatically appear in `claude-models` list!

## 🔧 Technical Details

- **Proxy**: LiteLLM on port 18080 (for remote_litellm runner type)
- **Local Engines**: MLX for Apple Silicon optimization, LM Studio for enhanced tool calling
- **Direct Connections**: Z.AI direct endpoints (no proxy needed)
- **API Compatible**: Works seamlessly with Claude Code interface
- **Environment**: Automatic .env loading for API keys
- **Config System**: YAML-based model configurations with metadata-driven alias generation
- **Service Management**: Unified stop/start functionality across all runner types

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

### Gemini Model Cache Conflicts
⚠️ **Important**: When using multiple Gemini models (Pro, Flash, Lite) via LiteLLM, you may encounter Vertex AI cache conflicts with errors like:

```
Model used by GenerateContent request (models/gemini-2.5-flash-lite) and CachedContent (models/gemini-2.5-pro) has to be the same.
```

This occurs because Google's Vertex AI service caches content based on message content rather than model names. When switching between different Gemini models, cached content from one model may conflict with another.

**Workarounds:**
- Use only one Gemini model type per session
- Wait for cached content to expire naturally (typically 1 hour)

This is a known limitation of Google's Vertex AI context caching system when used with LiteLLM.

### Setup Issues
- **`litellm` command not found**: Run `pip3 install 'litellm[proxy]' --user` and add the appropriate Python user bin directory to PATH (e.g., `export PATH="$HOME/Library/Python/$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)/bin:$PATH")`
- **`claude` command not found**: Install Claude Code from https://github.com/anthropics/claude-code
- **MLX installation**: Requires Apple Silicon Mac


## 📁 Project Structure

```
configs/                    # Model configuration files
├── local-*.yaml              # Local MLX models
├── lmstudio-*.yaml           # LM Studio models
├── remote-*.yaml             # Remote API models
└── openrouter-*.yaml         # OpenRouter models

scripts/                    # Management scripts
├── start-remote.sh           # Start remote models
├── start-local.sh            # Start local models
├── start-lmstudio.sh         # Start LM Studio models
├── claude-zai.sh             # Start Z.AI models directly
├── stop.sh                   # Stop all services
├── status.sh                 # Check status
├── setup-aliases.sh          # Create convenience aliases
├── setup-codex.sh            # Setup Codex CLI profiles
├── common-utils.sh           # Shared utility functions
└── download-lmstudio-model.sh # Download LM Studio models

setup.sh                   # Main setup script
.env                       # API keys (create this)
ai-aliases.sh              # Generated aliases (after setup)
litellm-proxy.log          # LiteLLM proxy logs
mlx-server.log             # MLX server logs (when applicable)
AGENTS.md                  # Claude Code agents documentation
```

---
*Note: The `claude` command by default connects to Anthropic's servers. To use your local models, either set the environment variables manually or use the `claudel` alias provided in the setup.*
