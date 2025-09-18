#!/bin/bash
# Generate Codex CLI configuration from repo model configs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/common-utils.sh"

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CODEX_CONFIG="$CODEX_HOME/config.toml"
MARKER_START="# >>> claude-multi-model codex config (generated) >>>"
MARKER_END="# <<< claude-multi-model codex config (generated) <<<"
PROVIDER_ID="claude_multi_model_proxy"
PROVIDER_TABLE="model_providers.$PROVIDER_ID"
PROVIDER_NAME="Claude Multi-Model LiteLLM Proxy"
PROVIDER_BASE_URL="http://localhost:18080/v1"
PROVIDER_ENV_KEY="LITELLM_API_KEY"
DEFAULT_APPROVAL="on-request"

mkdir -p "$CODEX_HOME"

categorize_configs "configs"

profiles=()

declare -a source_arrays=(configs_local_mlx[@] configs_local_lmstudio[@] configs_remote_litellm[@])

get_completion_model() {
    local file="$1"
    local completion_model=$(grep -m1 "completion_model:" "$file" | sed 's/.*completion_model:[[:space:]]*//')
    if [ -n "$completion_model" ]; then
        echo "$completion_model"
        return
    fi
    local model_name=$(grep -m1 "model_name:" "$file" | sed 's/.*model_name:[[:space:]]*//')
    if [ -n "$model_name" ]; then
        echo "$model_name"
        return
    fi
    echo ""
}

build_profile_id() {
    local alias_name="$1"
    if [[ "$alias_name" == claude-* ]]; then
        echo "codex-${alias_name#claude-}"
    else
        echo "codex-$alias_name"
    fi
}

for array_ref in "${source_arrays[@]}"; do
    for entry in "${!array_ref}"; do
        parse_config_entry "$entry" "config"
        profile_alias="$config_alias_name"
        completion_model=$(get_completion_model "$config_file")

        if [ -z "$completion_model" ]; then
            log_with_time "⚠️  Skipping $profile_alias (no completion model found)"
            continue
        fi

        profile_id=$(build_profile_id "$profile_alias")
        profiles+=("$profile_id|$completion_model|$profile_alias|$config_description")
    done
done

if [ ${#profiles[@]} -eq 0 ]; then
    echo "⚠️  No eligible configs found (local_mlx, local_lmstudio, remote_litellm)"
    echo "   Remote Z.AI configs are not currently supported by Codex auto-setup"
    exit 0
fi

default_profile=""

# Build generated block
TMP_GENERATED=$(mktemp)
{
    echo "$MARKER_START"
    echo "model_provider = \"$PROVIDER_ID\""

    default_profile="${profiles[0]%%|*}"
    echo "profile = \"$default_profile\""
    echo ""
    echo "[$PROVIDER_TABLE]"
    echo "name = \"$PROVIDER_NAME\""
    echo "base_url = \"$PROVIDER_BASE_URL\""
    echo "env_key = \"$PROVIDER_ENV_KEY\""
    echo "wire_api = \"chat\""
    echo "request_max_retries = 4"
    echo "stream_idle_timeout_ms = 300000"

    for profile_entry in "${profiles[@]}"; do
        IFS='|' read -r profile_id completion_model profile_alias profile_description <<< "$profile_entry"
        echo ""
        if [ -n "$profile_description" ]; then
            echo "# Source config: $profile_alias - $profile_description"
        else
            echo "# Source config: $profile_alias"
        fi
        echo "[profiles.\"$profile_id\"]"
        echo "model = \"$completion_model\""
        echo "model_provider = \"$PROVIDER_ID\""
        echo "approval_policy = \"$DEFAULT_APPROVAL\""
    done

    echo "$MARKER_END"
} > "$TMP_GENERATED"

sanitize_existing() {
    local infile="$1"
    local outfile="$2"
    python3 - "$MARKER_START" "$MARKER_END" "$infile" "$outfile" <<'PY'
import sys
start_marker, end_marker, in_path, out_path = sys.argv[1:5]
try:
    text = open(in_path, 'r', encoding='utf-8').read()
except FileNotFoundError:
    text = ''

if start_marker in text and end_marker in text:
    before, rest = text.split(start_marker, 1)
    _, after = rest.split(end_marker, 1)
    text = before.rstrip('\n') + '\n' + after.lstrip('\n')

with open(out_path, 'w', encoding='utf-8') as fh:
    if text.strip():
        if not text.endswith('\n'):
            text += '\n'
        fh.write(text)
PY
}

TMP_SANITIZED=$(mktemp)
sanitize_existing "$CODEX_CONFIG" "$TMP_SANITIZED"

TMP_FINAL=$(mktemp)
if [ -s "$TMP_SANITIZED" ]; then
    cat "$TMP_SANITIZED" > "$TMP_FINAL"
    if [ "$(tail -c1 "$TMP_FINAL" 2>/dev/null)" != $'\n' ]; then
        echo "" >> "$TMP_FINAL"
    fi
else
    : > "$TMP_FINAL"
fi

cat "$TMP_GENERATED" >> "$TMP_FINAL"

if [ -f "$CODEX_CONFIG" ]; then
    cp "$CODEX_CONFIG" "$CODEX_CONFIG.bak.$(date +%s)"
fi

mv "$TMP_FINAL" "$CODEX_CONFIG"
rm -f "$TMP_GENERATED" "$TMP_SANITIZED"

cat <<INFO
✅ Codex configuration updated: $CODEX_CONFIG
   - Provider ID: $PROVIDER_ID
   - Base URL: $PROVIDER_BASE_URL
   - Profiles generated: ${#profiles[@]}
   - Default profile: $default_profile

Set your LiteLLM API key before running Codex:
   export $PROVIDER_ENV_KEY=dummy-key

Run Codex with a generated profile, e.g.:
   codex --profile "$default_profile"
INFO
