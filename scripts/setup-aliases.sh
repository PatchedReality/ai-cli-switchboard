#!/bin/bash
# Dynamic Alias Setup - Automatically generates aliases from config metadata

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-utils.sh"

echo "🔧 Setting up AI model aliases dynamically..."
echo ""

# Start creating the alias file
cat > "$PROJECT_DIR/ai-aliases.sh" << STATIC_HEADER
#!/bin/bash
# AI Model Aliases - Source this file or add to your .bashrc/.zshrc

# Set the absolute path to the AI project directory
AI_DIR="$PROJECT_DIR"

codex_profile_runner() {
    local profile="\$1"
    local runner_type="\$2"
    local config_basename="\$3"
    shift 3

    case "\$runner_type" in
        local_mlx)
            "\$AI_DIR/scripts/start-local.sh" "\$AI_DIR/configs/\$config_basename" || return \$?
            ;;
        local_lmstudio)
            "\$AI_DIR/scripts/start-lmstudio.sh" "\$AI_DIR/configs/\$config_basename" || return \$?
            ;;
        remote_litellm)
            "\$AI_DIR/scripts/start-remote.sh" "\$AI_DIR/configs/\$config_basename" || return \$?
            ;;
    esac

    env LITELLM_API_KEY="\${LITELLM_API_KEY:-dummy-key}" codex --profile "\$profile" "\$@"
}

STATIC_HEADER

# Categorize all configs
categorize_configs "configs"

# Arrays to collect generated aliases by type
declare -a local_mlx_aliases=()
declare -a local_lmstudio_aliases=()
declare -a remote_litellm_aliases=()
declare -a remote_zai_aliases=()
declare -a all_aliases=()
declare -a codex_profiles=()

build_codex_profile_id() {
    local alias_name="$1"
    if [[ "$alias_name" == claude-* ]]; then
        echo "codex-${alias_name#claude-}"
    else
        echo "codex-$alias_name"
    fi
}

# Process local MLX configs
for entry in "${configs_local_mlx[@]}"; do
    parse_config_entry "$entry" "config"
    alias_command=$(generate_alias_command "$config_alias_name" "$config_runner_type" "$config_basename")
    if [ $? -eq 0 ]; then
        local_mlx_aliases+=("$alias_command")
        all_aliases+=("$config_alias_name:$config_description")
        codex_profile_id=$(build_codex_profile_id "$config_alias_name")
        codex_profiles+=("$codex_profile_id|$config_alias_name|$config_description|$config_runner_type|$config_basename")
    fi
done

# Process local LM Studio configs
for entry in "${configs_local_lmstudio[@]}"; do
    parse_config_entry "$entry" "config"
    alias_command=$(generate_alias_command "$config_alias_name" "$config_runner_type" "$config_basename")
    if [ $? -eq 0 ]; then
        local_lmstudio_aliases+=("$alias_command")
        all_aliases+=("$config_alias_name:$config_description")
        codex_profile_id=$(build_codex_profile_id "$config_alias_name")
        codex_profiles+=("$codex_profile_id|$config_alias_name|$config_description|$config_runner_type|$config_basename")
    fi
done

# Process remote LiteLLM configs
for entry in "${configs_remote_litellm[@]}"; do
    parse_config_entry "$entry" "config"
    alias_command=$(generate_alias_command "$config_alias_name" "$config_runner_type" "$config_basename")
    if [ $? -eq 0 ]; then
        remote_litellm_aliases+=("$alias_command")
        all_aliases+=("$config_alias_name:$config_description")
        codex_profile_id=$(build_codex_profile_id "$config_alias_name")
        codex_profiles+=("$codex_profile_id|$config_alias_name|$config_description|$config_runner_type|$config_basename")
    fi
done

# Process remote Z.AI configs
for entry in "${configs_remote_zai[@]}"; do
    parse_config_entry "$entry" "config"
    alias_command=$(generate_alias_command "$config_alias_name" "$config_runner_type" "$config_basename")
    if [ $? -eq 0 ]; then
        remote_zai_aliases+=("$alias_command")
        all_aliases+=("$config_alias_name:$config_description")
    fi
done

# Write aliases to file
{
    echo ""
    echo "# Local Models (MLX)"
    printf '%s\n' "${local_mlx_aliases[@]}"

    echo ""
    echo "# Local Models (LM Studio)"
    printf '%s\n' "${local_lmstudio_aliases[@]}"

    echo ""
    echo "# Remote Models (LiteLLM)"
    printf '%s\n' "${remote_litellm_aliases[@]}"

    echo ""
    echo "# Remote Models (Z.AI Direct)"
    printf '%s\n' "${remote_zai_aliases[@]}"

    if [ ${#codex_profiles[@]} -gt 0 ]; then
        echo ""
        echo "# Codex CLI Profiles"
        for codex_entry in "${codex_profiles[@]}"; do
            IFS='|' read -r codex_profile_id codex_source_alias codex_description codex_runner_type codex_config_basename <<< "$codex_entry"
            printf 'alias %s="codex_profile_runner %s %s %s"\n' \
                "$codex_profile_id" "$codex_profile_id" "$codex_runner_type" "$codex_config_basename"
        done
    fi

    echo ""
    echo "# Universal commands"
    echo 'alias claude-stop="$AI_DIR/scripts/stop.sh"'
    echo 'alias claude-status="$AI_DIR/scripts/status.sh"'
    echo 'alias codex-stop="$AI_DIR/scripts/stop.sh"'
    echo 'alias codex-status="$AI_DIR/scripts/status.sh"'
    echo ""
    echo "# Claude Code with local proxy"
    echo 'alias claudel="ANTHROPIC_BASE_URL=http://localhost:18080 ANTHROPIC_API_KEY=dummy-key claude"'
    echo ""
    echo "# Note: All start commands automatically stop existing services first"
    echo "# So no separate switch commands are needed"
    echo ""

    # Generate dynamic help command
    echo "# Show available models"
    echo -n 'alias claude-models="echo '\''Available Models:'\''; '

    # Helper function to add help entries
    add_help_section() {
        local section_name="$1"
        local emoji="$2"
        shift 2
        local aliases_array=("$@")

        if [ ${#aliases_array[@]} -gt 0 ]; then
            echo -n "echo '  $emoji $section_name:'; "
            for alias_desc in "${all_aliases[@]}"; do
                alias_name="${alias_desc%%:*}"
                description="${alias_desc#*:}"
                # Check if this alias belongs to current section
                for section_alias in "${aliases_array[@]}"; do
                    if [[ "$section_alias" == *"$alias_name="* ]]; then
                        echo -n "echo '      $alias_name - $description'; "
                        break
                    fi
                done
            done
        fi
    }

    # Add help sections
    add_help_section "Local (MLX)" "🏠" "${local_mlx_aliases[@]}"
    add_help_section "Local (LM Studio)" "🏪" "${local_lmstudio_aliases[@]}"

    if [ ${#remote_litellm_aliases[@]} -gt 0 ] || [ ${#remote_zai_aliases[@]} -gt 0 ]; then
        echo -n "echo '  ☁️  Remote:'; "
        for alias_desc in "${all_aliases[@]}"; do
            alias_name="${alias_desc%%:*}"
            description="${alias_desc#*:}"
            # Check if this is a remote alias
            is_remote=false
            for remote_alias in "${remote_litellm_aliases[@]}" "${remote_zai_aliases[@]}"; do
                if [[ "$remote_alias" == *"$alias_name="* ]]; then
                    is_remote=true
                    break
                fi
            done
            if [ "$is_remote" = true ]; then
                echo -n "echo '      $alias_name - $description'; "
            fi
        done
    fi

    echo -n "echo '  🎛️  Control:'; "
    echo -n "echo '      claude-stop - Stop all services'; "
    echo -n "echo '      claude-status - Check what'\''s running'; "
    echo -n "echo '      claude-models - Show this help'; "
    if [ ${#codex_profiles[@]} -gt 0 ]; then
        echo -n "echo '      codex-models - Show Codex profiles'; "
    fi
    echo -n "echo '  🖥️  Claude Code:'; "
    echo -n "echo '      claudel - Run Claude Code with local proxy'"
    echo '"'

    echo ""
    echo 'echo "🤖 AI model aliases loaded!"'
    echo 'echo "Usage: claude-models (to see all commands)"'
    echo 'echo "Use '\''claudel'\'' to run Claude Code with your local models"'
    if [ ${#codex_profiles[@]} -gt 0 ]; then
        echo 'echo "Use codex-models to list Codex CLI profiles"'
    fi

    if [ ${#codex_profiles[@]} -gt 0 ]; then
        echo ""
        echo "# Codex profile helper"
        echo -n 'alias codex-models="echo '\''Available Codex Profiles:'\''; '

        # Categorize codex profiles by runner type
        declare -a codex_local_mlx=()
        declare -a codex_local_lmstudio=()
        declare -a codex_remote_litellm=()

        for codex_entry in "${codex_profiles[@]}"; do
            IFS='|' read -r codex_profile_id codex_source_alias codex_description codex_runner_type codex_config_basename <<< "$codex_entry"
            case "$codex_runner_type" in
                "local_mlx")
                    codex_local_mlx+=("$codex_profile_id:$codex_description")
                    ;;
                "local_lmstudio")
                    codex_local_lmstudio+=("$codex_profile_id:$codex_description")
                    ;;
                "remote_litellm")
                    codex_remote_litellm+=("$codex_profile_id:$codex_description")
                    ;;
            esac
        done

        # Add local MLX section
        if [ ${#codex_local_mlx[@]} -gt 0 ]; then
            echo -n "echo '  🏠 Local (MLX):'; "
            for codex_desc in "${codex_local_mlx[@]}"; do
                codex_name="${codex_desc%%:*}"
                description="${codex_desc#*:}"
                echo -n "echo '      $codex_name - $description'; "
            done
        fi

        # Add local LM Studio section
        if [ ${#codex_local_lmstudio[@]} -gt 0 ]; then
            echo -n "echo '  🏪 Local (LM Studio):'; "
            for codex_desc in "${codex_local_lmstudio[@]}"; do
                codex_name="${codex_desc%%:*}"
                description="${codex_desc#*:}"
                echo -n "echo '      $codex_name - $description'; "
            done
        fi

        # Add remote section
        if [ ${#codex_remote_litellm[@]} -gt 0 ]; then
            echo -n "echo '  ☁️  Remote:'; "
            for codex_desc in "${codex_remote_litellm[@]}"; do
                codex_name="${codex_desc%%:*}"
                description="${codex_desc#*:}"
                echo -n "echo '      $codex_name - $description'; "
            done
        fi

        echo -n "echo '  🎛️  Control:'; "
        echo -n "echo '      codex-stop - Stop all services'; "
        echo -n "echo '      codex-status - Check what'\''s running'"
        echo '"'
    fi

} >> "$PROJECT_DIR/ai-aliases.sh"

chmod +x "$PROJECT_DIR/ai-aliases.sh"

# Calculate totals
total_aliases=$(( ${#local_mlx_aliases[@]} + ${#local_lmstudio_aliases[@]} + ${#remote_litellm_aliases[@]} + ${#remote_zai_aliases[@]} ))
config_count=$(find "$CONFIGS_DIR" -name "*.yaml" -exec grep -l "alias_config:" {} \; | wc -l | tr -d ' ')

echo "✅ Dynamic aliases created from $config_count config files!"
echo ""
echo "📋 Generated $total_aliases model aliases:"

# Show summary
if [ ${#local_mlx_aliases[@]} -gt 0 ]; then
    echo "   🏠 Local MLX Models: ${#local_mlx_aliases[@]}"
fi
if [ ${#local_lmstudio_aliases[@]} -gt 0 ]; then
    echo "   🏪 Local LM Studio Models: ${#local_lmstudio_aliases[@]}"
fi
if [ ${#remote_litellm_aliases[@]} -gt 0 ]; then
    echo "   ☁️  Remote LiteLLM Models: ${#remote_litellm_aliases[@]}"
fi
if [ ${#remote_zai_aliases[@]} -gt 0 ]; then
    echo "   🔗 Remote Z.AI Models: ${#remote_zai_aliases[@]}"
fi
if [ ${#codex_profiles[@]} -gt 0 ]; then
    echo "   🤖 Codex CLI Profiles: ${#codex_profiles[@]}"
fi

echo ""
echo "🔧 To activate aliases:"
echo "   source ai-aliases.sh"
echo ""
echo "🔧 To make permanent, add this to your ~/.bashrc or ~/.zshrc:"
echo "   source \"$PROJECT_DIR/ai-aliases.sh\""
