#!/bin/bash
# Common Utilities for Multi-Model AI Assistant Scripts
# Source this file from other scripts to access shared functionality

# Global variables
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)}"
PROJECT_DIR="${PROJECT_DIR:-$(dirname "$SCRIPT_DIR")}"
CONFIGS_DIR="${CONFIGS_DIR:-$PROJECT_DIR/configs}"

# YAML parsing function
get_yaml_value() {
    local file="$1"
    local key="$2"
    grep "^[[:space:]]*$key:" "$file" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/"//g' | sed 's/[[:space:]]*$//'
}

# Config metadata extraction - returns values via global variables
get_config_metadata() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    # Set global variables (avoid associative arrays for compatibility)
    CONFIG_NAME=$(get_yaml_value "$config_file" "name" || echo "Unknown")
    CONFIG_RUNNER_TYPE=$(get_yaml_value "$config_file" "runner_type" || echo "unknown")
    CONFIG_ALIAS_NAME=$(get_yaml_value "$config_file" "alias_name" || echo "")
    CONFIG_DESCRIPTION=$(get_yaml_value "$config_file" "description" || echo "")

    return 0
}

# Get script name for runner type
get_runner_script() {
    local runner_type="$1"
    local config_basename="$2"

    case "$runner_type" in
        "local_mlx")
            echo "start-local.sh"
            ;;
        "local_lmstudio")
            echo "start-lmstudio.sh"
            ;;
        "remote_litellm")
            echo "start-remote.sh"
            ;;
        "remote_zai")
            # Handle Z.AI direct scripts
            if [[ "$config_basename" == *"glm-4.5-zai.yaml" ]]; then
                echo "claude-zai.sh"
            elif [[ "$config_basename" == *"glm-4.5-air-zai.yaml" ]]; then
                echo "claude-zai.sh --air"
            else
                echo "start-remote.sh"
            fi
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

# Categorize configs by runner type
# Usage: categorize_configs result_var_prefix
# Creates arrays: ${prefix}_local_mlx, ${prefix}_local_lmstudio, ${prefix}_remote_litellm, ${prefix}_remote_zai
categorize_configs() {
    local prefix="$1"

    # Initialize arrays
    eval "${prefix}_local_mlx=()"
    eval "${prefix}_local_lmstudio=()"
    eval "${prefix}_remote_litellm=()"
    eval "${prefix}_remote_zai=()"

    for config_file in "$CONFIGS_DIR"/*.yaml; do
        if [ -f "$config_file" ]; then
            local config_basename=$(basename "$config_file")

            # Get metadata using global variables
            if get_config_metadata "$config_file"; then
                # Skip files without alias_config
                if [ -z "$CONFIG_ALIAS_NAME" ] || [ -z "$CONFIG_RUNNER_TYPE" ]; then
                    continue
                fi

                # Create config entry
                local config_entry="$config_file|$config_basename|$CONFIG_NAME|$CONFIG_RUNNER_TYPE|$CONFIG_ALIAS_NAME|$CONFIG_DESCRIPTION"

                # Add to appropriate array
                case "$CONFIG_RUNNER_TYPE" in
                    "local_mlx")
                        eval "${prefix}_local_mlx+=(\"\$config_entry\")"
                        ;;
                    "local_lmstudio")
                        eval "${prefix}_local_lmstudio+=(\"\$config_entry\")"
                        ;;
                    "remote_litellm")
                        eval "${prefix}_remote_litellm+=(\"\$config_entry\")"
                        ;;
                    "remote_zai")
                        eval "${prefix}_remote_zai+=(\"\$config_entry\")"
                        ;;
                esac
            fi
        fi
    done
}

# Parse config entry (used with categorize_configs)
# Usage: parse_config_entry "entry_string" var_prefix
# Creates variables: ${prefix}_file, ${prefix}_basename, ${prefix}_name, ${prefix}_runner_type, ${prefix}_alias_name, ${prefix}_description
parse_config_entry() {
    local entry="$1"
    local prefix="$2"

    IFS='|' read -r file basename name runner_type alias_name description <<< "$entry"

    eval "${prefix}_file=\"\$file\""
    eval "${prefix}_basename=\"\$basename\""
    eval "${prefix}_name=\"\$name\""
    eval "${prefix}_runner_type=\"\$runner_type\""
    eval "${prefix}_alias_name=\"\$alias_name\""
    eval "${prefix}_description=\"\$description\""
}

# Generate alias command for a config
generate_alias_command() {
    local alias_name="$1"
    local runner_type="$2"
    local config_basename="$3"

    local script_name=$(get_runner_script "$runner_type" "$config_basename")

    if [ "$script_name" = "unknown" ]; then
        echo "# Unknown runner type: $runner_type"
        return 1
    fi

    if [[ "$runner_type" == "remote_zai" && "$script_name" == "claude-zai.sh"* ]]; then
        # Special handling for Z.AI direct scripts - use claude_runner
        echo "alias $alias_name=\"claude_runner '\$AI_DIR/scripts/$script_name' ''\""
    else
        # Use claude_runner to start backend and launch Claude Code
        echo "alias $alias_name=\"claude_runner '\$AI_DIR/scripts/$script_name' '\$AI_DIR/configs/$config_basename'\""
    fi
}

# Count configs by type
count_configs_by_type() {
    local prefix="$1"

    local mlx_count=$(eval "echo \${#${prefix}_local_mlx[@]}")
    local lmstudio_count=$(eval "echo \${#${prefix}_local_lmstudio[@]}")
    local litellm_count=$(eval "echo \${#${prefix}_remote_litellm[@]}")
    local zai_count=$(eval "echo \${#${prefix}_remote_zai[@]}")

    echo "mlx:$mlx_count lmstudio:$lmstudio_count litellm:$litellm_count zai:$zai_count"
}

# Logging functions
log() { echo "$1"; }
log_with_time() { echo "$(date '+%H:%M:%S') $1"; }
error() { log_with_time "❌ ERROR: $1" >&2; exit 1; }

# Service management functions

# Check if a port is in use
is_port_in_use() {
    local port="$1"
    lsof -i:"$port" >/dev/null 2>&1
}

# Check if a process is running by PID
is_process_running() {
    local pid="$1"
    kill -0 "$pid" 2>/dev/null
}

# Stop a process by PID file
stop_process_by_pidfile() {
    local pidfile="$1"
    local service_name="${2:-Service}"

    if [ -f "$pidfile" ]; then
        local pid=$(cat "$pidfile")
        if is_process_running "$pid"; then
            log_with_time "📝 Stopping $service_name (PID: $pid)..."
            # Kill child processes first
            pkill -P "$pid" 2>/dev/null || true
            # Then kill the parent
            kill "$pid" 2>/dev/null || true
            # Wait a moment and force kill if still running
            sleep 1
            if is_process_running "$pid"; then
                kill -9 "$pid" 2>/dev/null || true
            fi
            return 0
        fi
        rm -f "$pidfile"
    fi
    return 1
}

# Wait for a port to become available
wait_for_port_free() {
    local port="$1"
    local timeout="${2:-10}"
    local count=0

    while is_port_in_use "$port" && [ $count -lt $timeout ]; do
        sleep 1
        count=$((count + 1))
    done

    if is_port_in_use "$port"; then
        return 1
    fi
    return 0
}

# Setup Python environment for user installs
setup_python_env() {
    local python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)
    export PATH="$HOME/Library/Python/$python_version/bin:$PATH"
}

# Load .env file if it exists
load_env_file() {
    local env_file="${1:-$PROJECT_DIR/.env}"

    if [ -f "$env_file" ]; then
        log_with_time "📄 Loading environment variables from $(basename "$env_file")"
        set -a  # Mark all new/modified vars for export
        source "$env_file"
        set +a  # Turn off auto-export
        return 0
    else
        log_with_time "⚠️  No .env file found at $env_file"
        return 1
    fi
}

# Validate config file and convert to absolute path
validate_config_file() {
    local config_file="$1"

    if [ -z "$config_file" ]; then
        error "Usage: $0 <config-file>"
    fi

    # Convert to absolute path
    if [[ "$config_file" = /* ]]; then
        echo "$config_file"
    else
        echo "$PROJECT_DIR/$config_file"
    fi
}

# Check if config file exists
check_config_exists() {
    local config_path="$1"

    if [ ! -f "$config_path" ]; then
        error "Config file not found: $config_path"
    fi
}

# Check if a command exists
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        if [ -n "$install_hint" ]; then
            error "$cmd not found. $install_hint"
        else
            error "$cmd not found"
        fi
    fi
}

# Stop all AI services (unified stop function)
stop_all_services() {
    local stopped=0

    log_with_time "🛑 Stopping all AI services..."

    # Stop LiteLLM Proxy
    if stop_process_by_pidfile "litellm-proxy.pid" "LiteLLM Proxy"; then
        stopped=1
    fi

    # Stop MLX Server
    if stop_process_by_pidfile "mlx-server.pid" "MLX Server"; then
        stopped=1
    fi

    # Stop LM Studio server and unload models
    local lms_path="$HOME/.lmstudio/bin/lms"
    if [ -f "$lms_path" ]; then
        chmod +x "$lms_path"

        # Check if LM Studio server is running
        if is_port_in_use 1234; then
            log_with_time "📝 Stopping LM Studio server..."
            "$lms_path" server stop >/dev/null 2>&1 || true
            stopped=1
        fi

        # Unload any loaded models
        log_with_time "📝 Unloading LM Studio models..."
        "$lms_path" unload --all >/dev/null 2>&1 || true
        sleep 1
        stopped=1
    fi

    # Clean up legacy PID files
    for pid_file in glm-*.pid; do
        if [ -f "$pid_file" ]; then
            if stop_process_by_pidfile "$pid_file" "legacy service"; then
                stopped=1
            fi
        fi
    done

    # Clean up current config tracker and temporary files
    rm -f current-config.txt
    if [ -f "temp-config.txt" ]; then
        local temp_config=$(cat temp-config.txt)
        rm -f "$temp_config"
        rm -f temp-config.txt
    fi

    if [ $stopped -eq 1 ]; then
        log_with_time "✅ All services stopped successfully!"
    else
        log_with_time "ℹ️  No running services found"
    fi

    return 0
}