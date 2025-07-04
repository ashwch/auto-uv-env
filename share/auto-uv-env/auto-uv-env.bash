# auto-uv-env.bash - Bash integration for auto-uv-env
# https://github.com/ashwch/auto-uv-env
#
# Add this to your ~/.bashrc:
#   source $(brew --prefix)/share/auto-uv-env/auto-uv-env.bash

# State tracking for proper deactivation
export _AUTO_UV_ENV_ACTIVATION_DIR=""

# Only set up if auto-uv-env is available
if command -v auto-uv-env >/dev/null 2>&1; then
    # Function to check and activate UV environments
    auto_uv_env() {
        # Performance optimization: Skip if no pyproject.toml
        if [[ ! -f "pyproject.toml" ]]; then
            # Handle deactivation if we left a Python project
            if [[ -n "${VIRTUAL_ENV:-}" ]] && [[ -n "${_AUTO_UV_ENV_ACTIVATION_DIR:-}" ]]; then
                # Only deactivate if we've actually left the project tree
                if [[ "$PWD" != "${_AUTO_UV_ENV_ACTIVATION_DIR}"* ]]; then
                    # Deactivate and clean up
                    if command -v deactivate >/dev/null 2>&1; then
                        deactivate
                    fi
                    unset _AUTO_UV_ENV_ACTIVATION_DIR
                    unset AUTO_UV_ENV_PYTHON_VERSION
                    [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && echo -e '\033[0;33m⬇️\033[0m  Deactivated UV environment'
                fi
            fi
            return 0
        fi

        # Performance optimization: If we're already in the right venv, skip the check
        if [[ -n "${VIRTUAL_ENV:-}" ]] && [[ "$PWD" == "${_AUTO_UV_ENV_ACTIVATION_DIR:-}"* ]]; then
            # We're still in the same project tree with an active venv
            return 0
        fi

        # Performance optimization: Check if .venv already exists and is activated
        local venv_dir="${AUTO_UV_ENV_VENV_NAME:-.venv}"
        if [[ -d "$venv_dir" ]] && [[ -f "$venv_dir/bin/activate" ]]; then
            # If venv exists and we're not in any venv, just activate it
            if [[ -z "${VIRTUAL_ENV:-}" ]]; then
                source "$venv_dir/bin/activate"
                export _AUTO_UV_ENV_ACTIVATION_DIR="$PWD"
                local python_version
                python_version=$(python --version 2>&1 | cut -d' ' -f2)
                [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $python_version)"
                export AUTO_UV_ENV_PYTHON_VERSION="$python_version"
                return 0
            fi
        fi

        # If VIRTUAL_ENV is not set but AUTO_UV_ENV_PYTHON_VERSION is, unset it.
        if [[ -z "${VIRTUAL_ENV:-}" ]] && [[ -n "${AUTO_UV_ENV_PYTHON_VERSION:-}" ]]; then
            unset AUTO_UV_ENV_PYTHON_VERSION
        fi

        local directives
        directives=$(auto-uv-env --check-safe "$PWD")

        # If no directives, nothing to do
        if [[ -z "$directives" ]]; then
            return 0
        fi

        local create_venv="" python_version="" msg_setup="" activate_path="" deactivate=""

        # Parse directives from output
        while IFS='=' read -r key value; do
            case "$key" in
                CREATE_VENV) create_venv="$value" ;;
                PYTHON_VERSION) python_version="$value" ;;
                MSG_SETUP) msg_setup="$value" ;;
                ACTIVATE) activate_path="$value" ;;
                DEACTIVATE) deactivate="$value" ;;
            esac
        done <<< "$directives"

            # Handle deactivation
            if [[ -n "$deactivate" ]]; then
                if command -v deactivate >/dev/null 2>&1; then
                    deactivate
                fi
                unset _AUTO_UV_ENV_ACTIVATION_DIR
                unset AUTO_UV_ENV_PYTHON_VERSION
                [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && echo -e '\033[0;33m⬇️\033[0m  Deactivated UV environment'
                return 0
            fi

            # Handle venv creation
            if [[ -n "$create_venv" ]]; then
                [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && [[ -n "$msg_setup" ]] && echo -e "\033[0;34m$msg_setup\033[0m"

                if [[ -n "$python_version" ]]; then
                    # Try specific Python version first
                    if ! uv python install "$python_version" 2>/dev/null; then
                        [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && echo -e "\033[0;34m🐍\033[0m Python $python_version not available, using default"
                    fi
                    if ! uv venv --python "$python_version" 2>/dev/null; then
                        if ! uv venv 2>/dev/null; then
                            echo -e "\033[0;31m❌\033[0m Failed to create virtual environment" >&2
                            return 1
                        fi
                    fi
                else
                    if ! uv venv 2>/dev/null; then
                        echo -e "\033[0;31m❌\033[0m Failed to create virtual environment" >&2
                        return 1
                    fi
                fi
                [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && echo -e "\033[0;32m✅\033[0m Virtual environment created"
            fi

            # Handle activation
            if [[ -n "$activate_path" ]] && [[ -f "$activate_path/bin/activate" ]]; then
                source "$activate_path/bin/activate"
                # Track where we activated from
                export _AUTO_UV_ENV_ACTIVATION_DIR="$PWD"
                local auto_uv_env_python_version_val
                auto_uv_env_python_version_val=$(python --version 2>&1 | cut -d' ' -f2)
                if [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]]; then
                    echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $auto_uv_env_python_version_val)"
                fi
                export AUTO_UV_ENV_PYTHON_VERSION="$auto_uv_env_python_version_val"
            fi
    }

    # Store the original PROMPT_COMMAND to chain properly
    if [[ -z "$_AUTO_UV_ENV_ORIGINAL_PROMPT_COMMAND" ]]; then
        _AUTO_UV_ENV_ORIGINAL_PROMPT_COMMAND="${PROMPT_COMMAND:-}"
    fi

    # Our prompt command function
    _auto_uv_env_prompt_command() {
        # Run original PROMPT_COMMAND first
        if [[ -n "$_AUTO_UV_ENV_ORIGINAL_PROMPT_COMMAND" ]]; then
            eval "$_AUTO_UV_ENV_ORIGINAL_PROMPT_COMMAND"
        fi

        # Check if directory changed
        if [[ "$PWD" != "${_AUTO_UV_ENV_LAST_PWD:-}" ]]; then
            _AUTO_UV_ENV_LAST_PWD="$PWD"
            auto_uv_env
        fi
    }

    # Properly chain PROMPT_COMMAND
    if [[ "$PROMPT_COMMAND" != *"_auto_uv_env_prompt_command"* ]]; then
        if [[ -n "$PROMPT_COMMAND" ]]; then
            PROMPT_COMMAND="$PROMPT_COMMAND; _auto_uv_env_prompt_command"
        else
            PROMPT_COMMAND="_auto_uv_env_prompt_command"
        fi
    fi

    # Run on shell startup
    auto_uv_env
else
    # Helpful message if auto-uv-env is not installed
    auto_uv_env() {
        if [[ -f "pyproject.toml" ]]; then
            echo "auto-uv-env not found. Install with: brew install ashwch/tap/auto-uv-env" >&2
        fi
    }
fi
