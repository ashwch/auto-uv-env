#!/usr/bin/env zsh
# auto-uv-env.zsh - ZSH integration for auto-uv-env
# https://github.com/ashwch/auto-uv-env
#
# Add this to your ~/.zshrc:
#   source $(brew --prefix)/share/auto-uv-env/auto-uv-env.zsh

# Only set up if auto-uv-env is available
if command -v auto-uv-env >/dev/null 2>&1; then
    # Function to check and activate UV environments
    auto_uv_env() {
        # If VIRTUAL_ENV is not set but AUTO_UV_ENV_PYTHON_VERSION is, unset it.
        if [[ -z "${VIRTUAL_ENV:-}" ]] && [[ -n "${AUTO_UV_ENV_PYTHON_VERSION:-}" ]]; then
            unset AUTO_UV_ENV_PYTHON_VERSION
        fi

        local state_file="/tmp/auto-uv-env.$.state"

        # Get state from auto-uv-env
        if ! auto-uv-env --check-safe "$PWD" > "$state_file" 2>&1; then
            return 0  # UV not available or other error
        fi

        # Process state file
        if [[ -f "$state_file" ]]; then
            local create_venv="" python_version="" msg_setup="" activate_path="" deactivate=""

            # Parse state file
            while IFS='=' read -r key value; do
                case "$key" in
                    CREATE_VENV) create_venv="$value" ;;
                    PYTHON_VERSION) python_version="$value" ;;
                    MSG_SETUP) msg_setup="$value" ;;
                    ACTIVATE) activate_path="$value" ;;
                    DEACTIVATE) deactivate="$value" ;;
                esac
            done < "$state_file"
            rm -f "$state_file"

            # Handle deactivation
            if [[ -n "$deactivate" ]]; then
                if command -v deactivate >/dev/null 2>&1; then
                    deactivate
                fi
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
                if [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]]; then
                    local activated_python_version
                    activated_python_version=$(python --version 2>&1 | cut -d' ' -f2)
                    echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $activated_python_version)"
                fi
                local activated_python_version_export=$(python --version 2>&1 | cut -d' ' -f2)
                export AUTO_UV_ENV_PYTHON_VERSION="$activated_python_version_export"
            fi
        fi
    }

    # Hook into directory changes
    autoload -U add-zsh-hook
    add-zsh-hook chpwd auto_uv_env

    # Run on shell startup if in a Python project
    auto_uv_env
else
    # Helpful message if auto-uv-env is not installed
    auto_uv_env() {
        if [[ -f "pyproject.toml" ]]; then
            echo "auto-uv-env not found. Install with: brew install ashwch/tap/auto-uv-env" >&2
        fi
    }
fi
