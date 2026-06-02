# auto-uv-env.bash - Bash integration for auto-uv-env
# https://github.com/ashwch/auto-uv-env
#
# Add this to your ~/.bashrc:
#   source $(brew --prefix)/share/auto-uv-env/auto-uv-env.bash

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

    _auto_uv_env_source_activate() {
        local activate_script="$1"
        local had_virtual_env_disable_prompt="${VIRTUAL_ENV_DISABLE_PROMPT+x}"
        local old_virtual_env_disable_prompt="${VIRTUAL_ENV_DISABLE_PROMPT-}"
        local activate_status=0

        # Prompt rendering belongs to the user's shell theme (starship, custom PS1,
        # etc.), not to the activation script. Tell virtualenv/venv activation logic
        # to leave PS1 alone while we still import the environment variables.
        VIRTUAL_ENV_DISABLE_PROMPT=1
        # shellcheck disable=SC1090
        source "$activate_script" || activate_status=$?

        if [[ -n "$had_virtual_env_disable_prompt" ]]; then
            VIRTUAL_ENV_DISABLE_PROMPT="$old_virtual_env_disable_prompt"
        else
            unset VIRTUAL_ENV_DISABLE_PROMPT
        fi

        return "$activate_status"
    }

    # Function to check and activate UV environments.
    #
    # First principles:
    # - The shell hook may fire more than once while one activation is still in progress.
    # - `source bin/activate` changes shell state, and some shells/plugins may react to that.
    # - If we start a second auto_uv_env run before the first one finishes, we can repeat
    #   setup work and print the setup message over and over.
    #
    # So this function follows two simple rules:
    # 1. Only one auto_uv_env run may be active at a time.
    # 2. Venv creation must target an explicit path, instead of relying on `cd` side effects.
    auto_uv_env() {
        # Guard against recursive re-entry (for example, if a sourced activation
        # script or nested shell callback triggers the hook again mid-run).
        if [[ "${_AUTO_UV_ENV_RUNNING:-0}" == "1" ]]; then
            return 0
        fi
        local _AUTO_UV_ENV_RUNNING=1

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

        # Performance optimization: Batch check for existing project .venv.
        local venv_dir="${AUTO_UV_ENV_VENV_NAME:-.venv}"
        local project_venv_path="$project_dir/$venv_dir"
        # Single stat call is faster than separate -d and -f checks.
        if [[ -f "$project_venv_path/bin/activate" ]] && [[ -z "${VIRTUAL_ENV:-}" ]]; then
            # Venv exists and we're not in any venv, just activate it
            _auto_uv_env_source_activate "$project_venv_path/bin/activate"
            export _AUTO_UV_ENV_ACTIVATION_DIR="$project_dir"

            # Performance: Only get Python version if we need to display it
            if [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]]; then
                local python_version python_full_version
                # Use shell parameter expansion instead of cut for performance
                # Handle case where python might not be available yet in UV environments
                if python_full_version=$(python --version 2>&1); then
                    python_version="${python_full_version#Python }"
                    echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $python_version)"
                    export AUTO_UV_ENV_PYTHON_VERSION="$python_version"
                else
                    echo -e "\033[0;32m🚀\033[0m UV environment activated (Python not installed)"
                    echo -e "\033[0;34mℹ️\033[0m  Run 'uv python install' to install Python"
                    export AUTO_UV_ENV_PYTHON_VERSION="unknown"
                fi
            else
                # Skip version check in quiet mode
                export AUTO_UV_ENV_PYTHON_VERSION="unknown"
            fi
            return 0
        fi

        # If VIRTUAL_ENV is not set but AUTO_UV_ENV_PYTHON_VERSION is, unset it.
        if [[ -z "${VIRTUAL_ENV:-}" ]] && [[ -n "${AUTO_UV_ENV_PYTHON_VERSION:-}" ]]; then
            unset AUTO_UV_ENV_PYTHON_VERSION
        fi

        local directives
        if ! directives=$(auto-uv-env --check-safe "$project_dir" 2>/dev/null); then
            return 0
        fi

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

                local venv_dir="${AUTO_UV_ENV_VENV_NAME:-.venv}"
                local created_venv_path="$project_dir/$venv_dir"

                # Create the venv at an explicit path.
                #
                # Why this matters:
                # - Older code changed into the project directory and then ran `uv venv`.
                # - That worked, but it mixed "where the shell is standing" with
                #   "which project owns the venv".
                # - In hook-driven code, changing directories can trigger more shell work.
                #
                # Using an explicit path keeps the operation declarative:
                #   project root -> desired venv path -> create exactly there
                if [[ -n "$python_version" ]]; then
                    # Try specific Python version first
                    if ! uv python install "$python_version" 2>/dev/null; then
                        [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && echo -e "\033[0;34m🐍\033[0m Python $python_version not available, using default"
                    fi
                    if ! uv venv --python "$python_version" "$created_venv_path" 2>/dev/null; then
                        if ! uv venv "$created_venv_path" 2>/dev/null; then
                            echo -e "\033[0;31m❌\033[0m Failed to create virtual environment" >&2
                            return 1
                        fi
                    fi
                else
                    if ! uv venv "$created_venv_path" 2>/dev/null; then
                        echo -e "\033[0;31m❌\033[0m Failed to create virtual environment" >&2
                        return 1
                    fi
                fi
                [[ "${AUTO_UV_ENV_QUIET:-0}" != "1" ]] && echo -e "\033[0;32m✅\033[0m Virtual environment created"

                # After creating a new environment, activate it
                if [[ -f "$created_venv_path/bin/activate" ]]; then
                    _auto_uv_env_source_activate "$created_venv_path/bin/activate"
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
                _auto_uv_env_source_activate "$activate_path/bin/activate"
                # Track where we activated from
                local activation_project_dir
                activation_project_dir="$(_auto_uv_env_project_from_venv_path "$activate_path")"
                export _AUTO_UV_ENV_ACTIVATION_DIR="$activation_project_dir"
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
    }

    # Store the original PROMPT_COMMAND to chain properly
    if [[ -z "${_AUTO_UV_ENV_ORIGINAL_PROMPT_COMMAND:-}" ]]; then
        _AUTO_UV_ENV_ORIGINAL_PROMPT_COMMAND="${PROMPT_COMMAND:-}"
    fi

    # Our prompt command function
    _auto_uv_env_prompt_command() {
        # Run original PROMPT_COMMAND first
        if [[ -n "${_AUTO_UV_ENV_ORIGINAL_PROMPT_COMMAND:-}" ]]; then
            eval "$_AUTO_UV_ENV_ORIGINAL_PROMPT_COMMAND"
        fi

        # Check if directory changed
        if [[ "$PWD" != "${_AUTO_UV_ENV_LAST_PWD:-}" ]]; then
            _AUTO_UV_ENV_LAST_PWD="$PWD"
            auto_uv_env
        fi
    }

    # Properly chain PROMPT_COMMAND
    if [[ "${PROMPT_COMMAND:-}" != *"_auto_uv_env_prompt_command"* ]]; then
        if [[ -n "${PROMPT_COMMAND:-}" ]]; then
            PROMPT_COMMAND="$PROMPT_COMMAND; _auto_uv_env_prompt_command"
        else
            PROMPT_COMMAND="_auto_uv_env_prompt_command"
        fi
    fi

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
