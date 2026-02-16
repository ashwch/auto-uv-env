#!/usr/bin/env zsh
# auto-uv-env.zsh - ZSH integration for auto-uv-env
# https://github.com/ashwch/auto-uv-env
#
# Add this to your ~/.zshrc:
#   source $(brew --prefix)/share/auto-uv-env/auto-uv-env.zsh

# State tracking for proper deactivation
export _AUTO_UV_ENV_ACTIVATION_DIR=""

# Only set up if auto-uv-env is available
if command -v auto-uv-env >/dev/null 2>&1; then
    _auto_uv_env_find_project_dir() {
        local dir="$PWD"
        while true; do
            if [[ -f "$dir/.auto-uv-env-ignore" ]]; then
                return 2
            fi
            if [[ -f "$dir/pyproject.toml" ]]; then
                echo "$dir"
                return 0
            fi
            [[ "$dir" == "/" ]] && return 1
            dir="${dir%/*}"
            [[ -z "$dir" ]] && dir="/"
        done
    }

    _auto_uv_env_is_within_dir() {
        local path="$1"
        local base="$2"

        [[ -n "$base" ]] || return 1

        if [[ "$base" != "/" ]]; then
            base="${base%/}"
        fi
        if [[ "$path" != "/" ]]; then
            path="${path%/}"
        fi

        if [[ "$base" == "/" ]]; then
            [[ "$path" == /* ]]
        else
            [[ "$path" == "$base" || "$path" == "$base/"* ]]
        fi
    }

    _auto_uv_env_project_from_venv_path() {
        local venv_path="$1"
        local venv_dir="${AUTO_UV_ENV_VENV_NAME:-.venv}"
        local suffix="/$venv_dir"

        case "$venv_path" in
            *"$suffix")
                echo "${venv_path%"$suffix"}"
                ;;
            *)
                echo "$PWD"
                ;;
        esac
    }

    # Function to check and activate UV environments
    auto_uv_env() {
        # If we're in a managed venv, first verify that it still exists.
        if [[ -n "${VIRTUAL_ENV:-}" ]] && [[ -n "${_AUTO_UV_ENV_ACTIVATION_DIR:-}" ]] && _auto_uv_env_is_within_dir "$PWD" "${_AUTO_UV_ENV_ACTIVATION_DIR}"; then
            if [[ ! -d "${VIRTUAL_ENV:-}" ]]; then
                if [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]]; then
                    echo -e '\033[0;33m⚠️\033[0m  Virtual environment was deleted, cleaning up...'
                fi
                unset VIRTUAL_ENV
                unset _AUTO_UV_ENV_ACTIVATION_DIR
                unset AUTO_UV_ENV_PYTHON_VERSION
            fi
        fi

        local project_dir="" project_status=0
        project_dir=$(_auto_uv_env_find_project_dir) || project_status=$?

        # Ignore marker in current path takes precedence over parent project roots.
        if [[ $project_status -eq 2 ]]; then
            if [[ -n "${VIRTUAL_ENV:-}" ]] && [[ -n "${_AUTO_UV_ENV_ACTIVATION_DIR:-}" ]]; then
                if command -v deactivate >/dev/null 2>&1; then
                    deactivate
                fi
                unset _AUTO_UV_ENV_ACTIVATION_DIR
                unset AUTO_UV_ENV_PYTHON_VERSION
                [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && echo -e '\033[0;33m⬇️\033[0m  Deactivated UV environment'
            fi
            return 0
        fi

        # No project in current tree: only handle deactivation when leaving managed tree.
        if [[ $project_status -ne 0 ]] || [[ -z "$project_dir" ]]; then
            if [[ -n "${VIRTUAL_ENV:-}" ]] && [[ -n "${_AUTO_UV_ENV_ACTIVATION_DIR:-}" ]]; then
                if ! _auto_uv_env_is_within_dir "$PWD" "${_AUTO_UV_ENV_ACTIVATION_DIR}"; then
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

        # Managed venv already active for this discovered project root.
        if [[ -n "${VIRTUAL_ENV:-}" ]] && [[ "${_AUTO_UV_ENV_ACTIVATION_DIR:-}" == "$project_dir" ]] && [[ -d "${VIRTUAL_ENV:-}" ]]; then
            return 0
        fi

        # Performance optimization: Batch check for .venv existence
        local venv_dir="${AUTO_UV_ENV_VENV_NAME:-.venv}"
        local project_venv_path="$project_dir/$venv_dir"
        # Single stat call is faster than separate -d and -f checks
        if [[ -f "$project_venv_path/bin/activate" ]] && [[ -z "${VIRTUAL_ENV:-}" ]]; then
            # Venv exists and we're not in any venv, just activate it
            source "$project_venv_path/bin/activate"
            export _AUTO_UV_ENV_ACTIVATION_DIR="$project_dir"
            local python_version python_full_version
            # Use shell parameter expansion instead of cut for performance
            # Handle case where python might not be available yet in UV environments
            if python_full_version=$(python --version 2>&1); then
                python_version="${python_full_version#Python }"
                [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $python_version)"
                export AUTO_UV_ENV_PYTHON_VERSION="$python_version"
            else
                if [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]]; then
                    echo -e "\033[0;32m🚀\033[0m UV environment activated (Python not installed)"
                    echo -e "\033[0;34mℹ️\033[0m  Run 'uv python install' to install Python"
                fi
                export AUTO_UV_ENV_PYTHON_VERSION="unknown"
            fi
            return 0
        fi

        # If VIRTUAL_ENV is not set but AUTO_UV_ENV_PYTHON_VERSION is, unset it.
        if [[ -z "${VIRTUAL_ENV:-}" ]] && [[ -n "${AUTO_UV_ENV_PYTHON_VERSION:-}" ]]; then
            unset AUTO_UV_ENV_PYTHON_VERSION
        fi

        local state_file="/tmp/auto-uv-env.$.state"

        # Get state from auto-uv-env
        if ! auto-uv-env --check-safe "$project_dir" > "$state_file" 2>&1; then
            rm -f "$state_file"
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
                    if ! (cd "$project_dir" && uv venv --python "$python_version" 2>/dev/null); then
                        if ! (cd "$project_dir" && uv venv 2>/dev/null); then
                            echo -e "\033[0;31m❌\033[0m Failed to create virtual environment" >&2
                            return 1
                        fi
                    fi
                else
                    if ! (cd "$project_dir" && uv venv 2>/dev/null); then
                        echo -e "\033[0;31m❌\033[0m Failed to create virtual environment" >&2
                        return 1
                    fi
                fi
                [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && echo -e "\033[0;32m✅\033[0m Virtual environment created"

                # After creating a new environment, activate it
                local venv_dir="${AUTO_UV_ENV_VENV_NAME:-.venv}"
                local created_venv_path="$project_dir/$venv_dir"
                if [[ -f "$created_venv_path/bin/activate" ]]; then
                    source "$created_venv_path/bin/activate"
                    export _AUTO_UV_ENV_ACTIVATION_DIR="$project_dir"
                    local auto_uv_env_python_version_val python_full_version
                    if python_full_version=$(python --version 2>&1); then
                        auto_uv_env_python_version_val="${python_full_version#Python }"
                        if [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]]; then
                            echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $auto_uv_env_python_version_val)"
                        fi
                        export AUTO_UV_ENV_PYTHON_VERSION="$auto_uv_env_python_version_val"
                    else
                        if [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]]; then
                            echo -e "\033[0;32m🚀\033[0m UV environment activated (Python not installed)"
                            echo -e "\033[0;34mℹ️\033[0m  Run 'uv python install' to install Python"
                        fi
                        export AUTO_UV_ENV_PYTHON_VERSION="unknown"
                    fi
                fi
            fi

            # Handle activation
            if [[ -n "$activate_path" ]] && [[ -f "$activate_path/bin/activate" ]]; then
                source "$activate_path/bin/activate"
                # Track where we activated from
                export _AUTO_UV_ENV_ACTIVATION_DIR="$(_auto_uv_env_project_from_venv_path "$activate_path")"
                local auto_uv_env_python_version_val python_full_version
                # Use shell parameter expansion instead of cut for performance
                # Handle case where python might not be available yet in UV environments
                if python_full_version=$(python --version 2>&1); then
                    auto_uv_env_python_version_val="${python_full_version#Python }"
                    if [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]]; then
                        echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $auto_uv_env_python_version_val)"
                    fi
                    export AUTO_UV_ENV_PYTHON_VERSION="$auto_uv_env_python_version_val"
                else
                    if [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]]; then
                        echo -e "\033[0;32m🚀\033[0m UV environment activated (Python not installed)"
                        echo -e "\033[0;34mℹ️\033[0m  Run 'uv python install' to install Python"
                    fi
                    export AUTO_UV_ENV_PYTHON_VERSION="unknown"
                fi
            fi
        fi
    }

    # Hook into directory changes
    autoload -U add-zsh-hook
    add-zsh-hook chpwd auto_uv_env

    # Lazy loading: check on startup only if we're already in a managed project tree.
    _auto_uv_env_startup_project_dir="$(_auto_uv_env_find_project_dir)" || true
    if [[ -n "${_auto_uv_env_startup_project_dir:-}" ]]; then
        auto_uv_env
    fi
    unset _auto_uv_env_startup_project_dir
else
    # Helpful message if auto-uv-env is not installed
    auto_uv_env() {
        if [[ -f "pyproject.toml" ]]; then
            echo "auto-uv-env not found. Install with: brew install ashwch/tap/auto-uv-env" >&2
        fi
    }
fi
