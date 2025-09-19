# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an AI CLI Switchboard that allows Claude Code or Codex CLI to work as frontends to any cloud or local LLM on Apple Silicon. It provides a unified interface to connect locally via LiteLLM + MLX or LM Studio, or remotely via Z.AI, Gemini/Google AI Studio, DeepSeek, or OpenRouter.

## Essential Commands

### Setup and Installation
```bash
./setup.sh                           # Install dependencies (LiteLLM, MLX, etc.)
./scripts/setup-aliases.sh           # Generate convenience aliases from configs
source ai-aliases.sh                 # Load generated aliases
./scripts/setup-codex.sh             # Setup Codex CLI profiles (if Codex installed)
```

### Starting Models
```bash
# Remote models (require API keys in .env)
./scripts/start-remote.sh configs/remote-deepseek.yaml
./scripts/start-remote.sh configs/remote-gemini-pro.yaml

# Local MLX models (Apple Silicon only)
./scripts/start-local.sh configs/local-glm-9b.yaml
./scripts/start-local.sh configs/local-glm-32b.yaml

# LM Studio models (better tool calling)
./scripts/start-lmstudio.sh configs/lmstudio-llama-groq-tool.yaml

# Z.AI direct (no proxy needed)
./scripts/claude-zai.sh              # GLM-4.5
./scripts/claude-zai.sh --air         # GLM-4.5 Air
```

### Service Management
```bash
./scripts/stop.sh                    # Stop all running services
./scripts/status.sh                  # Check what's currently running
```

### Using with Claude Code
```bash
# Manual approach
ANTHROPIC_BASE_URL=http://localhost:18080 ANTHROPIC_API_KEY=dummy-key claude

# Using generated alias (after sourcing ai-aliases.sh)
claudel

# Using specific model aliases (after setup-aliases.sh)
claude-remote-deepseek               # Start DeepSeek and keep running
claude-local-glm-9b                  # Start local GLM-9B
claude-lmstudio-llama-groq           # Start LM Studio Llama model
claude-models                        # List all available model commands
```

### Using with Codex CLI
```bash
# After setup-codex.sh
codex-local-glm-9b                   # Auto-start backend + launch Codex
codex-lmstudio-llama-groq           # Start LM Studio + Codex
codex-models                         # List all Codex profiles
```

## Architecture Overview

### Core Components

1. **Configuration System (`configs/`)**
   - YAML files define model configurations with standardized structure
   - Each config contains: model_list, litellm_settings, general_settings, model_info, alias_config
   - Naming convention: `{runner_type}-{model_name}.yaml`

2. **Runner Types (4 deployment strategies)**
   - `local_mlx`: Apple Silicon MLX framework (scripts/start-local.sh)
   - `local_lmstudio`: LM Studio with enhanced tool calling (scripts/start-lmstudio.sh)
   - `remote_litellm`: Remote APIs via LiteLLM proxy (scripts/start-remote.sh)
   - `remote_zai`: Z.AI direct connection (scripts/claude-zai.sh)

3. **Service Management (`scripts/`)**
   - `common-utils.sh`: Shared utility functions for all scripts
   - Port management (18080 for LiteLLM proxy, 18081 for MLX, 1234 for LM Studio)
   - PID file tracking for service lifecycle
   - Unified stop/start functionality across runner types

4. **Dynamic Alias Generation**
   - `setup-aliases.sh` reads all config files and generates `ai-aliases.sh`
   - Metadata-driven: each config's `alias_config` section defines generated aliases
   - Supports both Claude Code and Codex CLI workflows

### Configuration File Structure

All config files follow this pattern:
```yaml
# LiteLLM configuration
model_list:
  - model_name: model-id
    litellm_params:
      model: provider/model-name
      api_key: ${ENV_VAR} # for remote
      api_base: http://localhost:port/v1 # for local

# Model metadata (used by scripts)
model_info:
  name: "Display Name"
  type: "local|remote"
  provider: "Provider Name"

# Alias generation (critical for dynamic aliases)
alias_config:
  alias_name: "claude-category-name"
  runner_type: "local_mlx|local_lmstudio|remote_litellm|remote_zai"
  description: "Brief description"
```

### Service Architecture

- **LiteLLM Proxy**: Central proxy on port 18080 providing OpenAI-compatible API
- **MLX Server**: Local Apple Silicon server on port 18081 for MLX models
- **LM Studio**: Local server on port 1234 with model management
- **Z.AI Direct**: No proxy needed, direct API calls

### Key Files and Their Roles

- `setup.sh`: Master setup script with dependency installation and compatibility checks
- `scripts/common-utils.sh`: Shared functions for YAML parsing, service management, config validation
- `scripts/start-{type}.sh`: Runner-specific startup scripts
- `ai-aliases.sh`: Generated file with convenience aliases (do not edit manually)
- `.env`: API keys (never commit)
- `*-proxy.log`, `*.pid`: Runtime artifacts in repo root

## Development Workflow

### Adding New Models

1. **Create config file** in `configs/` following naming convention
2. **Copy existing config** as template, modify for new model
3. **Ensure alias_config section** is properly filled for automatic alias generation
4. **Regenerate aliases**: `./scripts/setup-aliases.sh && source ai-aliases.sh`
5. **Test**: Use generated alias to start model and verify with `./scripts/status.sh`

### Testing Models

```bash
# Smoke test sequence
./scripts/start-{type}.sh configs/{model}.yaml
./scripts/status.sh
curl -H "Authorization: Bearer dummy-key" http://localhost:18080/v1/models
tail -f litellm-proxy.log # Watch for errors
```

### Configuration Validation

- Ports must be free before starting (scripts auto-stop conflicting services)
- Environment variables must be set in `.env` for remote models
- MLX models require Apple Silicon + MLX installation
- LM Studio models require models downloaded through LM Studio

## Environment and Security

### Required Environment Variables (.env)
```bash
DEEPSEEK_API_KEY=sk-...
GEMINI_API_KEY=AIza...
OPENROUTER_API_KEY=sk-or-v1-...
ZAI_API_KEY=...
```

### File Security
- Never commit `.env`, log files, or PID files
- Runtime artifacts land in repo root: `litellm-proxy.log`, `mlx-server.log`, `*.pid`
- Clean up before commits: `./scripts/stop.sh` removes PID files

## Troubleshooting

### Common Issues
- **Port conflicts**: Scripts auto-stop existing services on startup
- **MLX not working**: Requires Apple Silicon Mac + Python 3.9+
- **API key errors**: Check `.env` file and variable names
- **Model not found**: MLX models auto-download on first use

### Log Locations
- LiteLLM: `tail -f litellm-proxy.log`
- MLX: `tail -f mlx-server.log`
- Service status: `./scripts/status.sh`

### Service Recovery
```bash
./scripts/stop.sh          # Stop everything
./scripts/status.sh        # Verify clean state
./scripts/start-{type}.sh configs/{model}.yaml
```

## Integration Notes

- Claude Code connects via `ANTHROPIC_BASE_URL=http://localhost:18080` and `ANTHROPIC_API_KEY=dummy-key`
- Codex CLI uses profiles pointing to `http://localhost:18080/v1` with `LITELLM_API_KEY=dummy-key`
- All models appear as OpenAI-compatible endpoints through the proxy
- Generated aliases automatically handle backend startup and connection