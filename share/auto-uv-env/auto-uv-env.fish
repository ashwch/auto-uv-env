# auto-uv-env.fish - Fish integration for auto-uv-env
# https://github.com/ashwch/auto-uv-env
#
# Add this to your ~/.config/fish/config.fish:
#   source (brew --prefix)/share/auto-uv-env/auto-uv-env.fish

# State tracking for proper deactivation
set -gx _AUTO_UV_ENV_ACTIVATION_DIR ""

# Only set up if auto-uv-env is available
if command -v auto-uv-env >/dev/null 2>&1
    function _auto_uv_env_find_project_dir
        set -l dir $PWD

        while true
            if test -f "$dir/.auto-uv-env-ignore"
                return 2
            end

            if test -f "$dir/pyproject.toml"
                echo $dir
                return 0
            end

            if test "$dir" = "/"
                return 1
            end

            set dir (string replace -r '/[^/]+$' '' "$dir")
            if test -z "$dir"
                set dir "/"
            end
        end
    end

    function _auto_uv_env_is_within_dir
        set -l path "$argv[1]"
        set -l base "$argv[2]"

        if test -z "$base"
            return 1
        end

        if test "$base" != "/"
            set base (string replace -r '/+$' '' "$base")
        end
        if test "$path" != "/"
            set path (string replace -r '/+$' '' "$path")
        end

        if test "$base" = "/"
            string match -rq '^/' "$path"
            return $status
        end

        set -l base_regex (string escape --style=regex "$base")
        string match -rq "^$base_regex(/|$)" "$path"
    end

    function _auto_uv_env_project_from_venv_path
        set -l venv_path "$argv[1]"
        set -l venv_dir (test -n "$AUTO_UV_ENV_VENV_NAME"; and echo $AUTO_UV_ENV_VENV_NAME; or echo ".venv")
        set -l suffix "/$venv_dir"
        set -l suffix_regex (string escape --style=regex "$suffix")

        if string match -rq "$suffix_regex$" "$venv_path"
            echo (string replace -r "$suffix_regex$" "" "$venv_path")
        else
            echo "$PWD"
        end
    end

    # Function to check and activate UV environments
    function auto_uv_env
        # If we're in a managed venv, first verify that it still exists.
        if test -n "$VIRTUAL_ENV"; and test -n "$_AUTO_UV_ENV_ACTIVATION_DIR"; and _auto_uv_env_is_within_dir "$PWD" "$_AUTO_UV_ENV_ACTIVATION_DIR"
            if not test -d "$VIRTUAL_ENV"
                if test "$AUTO_UV_ENV_QUIET" != "1"
                    echo -e '\033[0;33m⚠️\033[0m  Virtual environment was deleted, cleaning up...'
                end
                set -e VIRTUAL_ENV
                set -e _AUTO_UV_ENV_ACTIVATION_DIR
                set -e AUTO_UV_ENV_PYTHON_VERSION
            end
        end

        set -l project_dir (_auto_uv_env_find_project_dir)
        set -l project_status $status

        # Ignore marker in current path takes precedence over parent project roots.
        if test "$project_status" -eq 2
            if test -n "$VIRTUAL_ENV"; and test -n "$_AUTO_UV_ENV_ACTIVATION_DIR"
                if command -v deactivate >/dev/null 2>&1
                    deactivate
                end
                set -e _AUTO_UV_ENV_ACTIVATION_DIR
                set -e AUTO_UV_ENV_PYTHON_VERSION
                if test "$AUTO_UV_ENV_QUIET" != "1"
                    echo -e '\033[0;33m⬇️\033[0m  Deactivated UV environment'
                end
            end
            return 0
        end

        # No project in current tree: only handle deactivation when leaving managed tree.
        if test "$project_status" -ne 0 -o -z "$project_dir"
            if test -n "$VIRTUAL_ENV"; and test -n "$_AUTO_UV_ENV_ACTIVATION_DIR"
                if not _auto_uv_env_is_within_dir "$PWD" "$_AUTO_UV_ENV_ACTIVATION_DIR"
                    if command -v deactivate >/dev/null 2>&1
                        deactivate
                    end
                    set -e _AUTO_UV_ENV_ACTIVATION_DIR
                    set -e AUTO_UV_ENV_PYTHON_VERSION
                    if test "$AUTO_UV_ENV_QUIET" != "1"
                        echo -e '\033[0;33m⬇️\033[0m  Deactivated UV environment'
                    end
                end
            end
            return 0
        end

        # Managed venv already active for this discovered project root.
        if test -n "$VIRTUAL_ENV"; and test "$_AUTO_UV_ENV_ACTIVATION_DIR" = "$project_dir"; and test -d "$VIRTUAL_ENV"
            return 0
        end

        # Performance optimization: Batch check for .venv existence
        set -l venv_dir (test -n "$AUTO_UV_ENV_VENV_NAME"; and echo $AUTO_UV_ENV_VENV_NAME; or echo ".venv")
        set -l project_venv_path "$project_dir/$venv_dir"
        # Single stat call is faster than separate -d and -f checks
        if test -f "$project_venv_path/bin/activate.fish" -a -z "$VIRTUAL_ENV"
            # Venv exists and we're not in any venv, just activate it
            source "$project_venv_path/bin/activate.fish"
            set -gx _AUTO_UV_ENV_ACTIVATION_DIR "$project_dir"
            # Use fish string manipulation instead of cut for performance
            # Handle case where python might not be available yet in UV environments
            if set -l python_full_version (python --version 2>&1)
                set -l python_version (string replace "Python " "" "$python_full_version")
                if test "$AUTO_UV_ENV_QUIET" != "1"
                    echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $python_version)"
                end
                set -gx AUTO_UV_ENV_PYTHON_VERSION "$python_version"
            else
                if test "$AUTO_UV_ENV_QUIET" != "1"
                    echo -e "\033[0;32m🚀\033[0m UV environment activated (Python not installed)"
                    echo -e "\033[0;34mℹ️\033[0m  Run 'uv python install' to install Python"
                end
                set -gx AUTO_UV_ENV_PYTHON_VERSION "unknown"
            end
            return 0
        end

        # If VIRTUAL_ENV is not set but AUTO_UV_ENV_PYTHON_VERSION is, unset it.
        if test -z "$VIRTUAL_ENV"; and test -n "$AUTO_UV_ENV_PYTHON_VERSION"
            set -e AUTO_UV_ENV_PYTHON_VERSION
        end

        set -l state_file "/tmp/auto-uv-env."(echo %self)".state"

        # Get state from auto-uv-env
        if not auto-uv-env --check-safe "$project_dir" > $state_file 2>&1
            rm -f $state_file
            return 0  # UV not available or other error
        end

        # Process state file
        if test -f $state_file
            set -l create_venv ""
            set -l python_version ""
            set -l msg_setup ""
            set -l activate_path ""
            set -l deactivate ""

            # Parse state file
            for line in (cat $state_file)
                set -l parts (string split '=' $line)
                if test (count $parts) -ge 2
                    set -l key $parts[1]
                    set -l value (string join '=' $parts[2..-1])

                    switch $key
                        case CREATE_VENV
                            set create_venv $value
                        case PYTHON_VERSION
                            set python_version $value
                        case MSG_SETUP
                            set msg_setup $value
                        case ACTIVATE
                            set activate_path $value
                        case DEACTIVATE
                            set deactivate $value
                    end
                end
            end
            rm -f $state_file

            # Handle deactivation
            if test -n "$deactivate"
                if command -v deactivate >/dev/null 2>&1
                    deactivate
                end
                set -e _AUTO_UV_ENV_ACTIVATION_DIR
                set -e AUTO_UV_ENV_PYTHON_VERSION
                if test "$AUTO_UV_ENV_QUIET" != "1"
                    echo -e '\033[0;33m⬇️\033[0m  Deactivated UV environment'
                end
                return 0
            end

            # Handle venv creation
            if test -n "$create_venv"
                if test "$AUTO_UV_ENV_QUIET" != "1" -a -n "$msg_setup"
                    echo -e "\033[0;34m$msg_setup\033[0m"
                end

                set -l old_pwd $PWD
                if test -n "$python_version"
                    # Try specific Python version first
                    if not uv python install "$python_version" 2>/dev/null
                        if test "$AUTO_UV_ENV_QUIET" != "1"
                            echo -e "\033[0;34m🐍\033[0m Python $python_version not available, using default"
                        end
                    end
                    cd "$project_dir"
                    if not uv venv --python "$python_version" 2>/dev/null
                        if not uv venv 2>/dev/null
                            cd "$old_pwd"
                            echo -e "\033[0;31m❌\033[0m Failed to create virtual environment" >&2
                            return 1
                        end
                    end
                    cd "$old_pwd"
                else
                    cd "$project_dir"
                    if not uv venv 2>/dev/null
                        cd "$old_pwd"
                        echo -e "\033[0;31m❌\033[0m Failed to create virtual environment" >&2
                        return 1
                    end
                    cd "$old_pwd"
                end
                if test "$AUTO_UV_ENV_QUIET" != "1"
                    echo -e "\033[0;32m✅\033[0m Virtual environment created"
                end

                # After creating a new environment, activate it
                set -l venv_dir (test -n "$AUTO_UV_ENV_VENV_NAME"; and echo $AUTO_UV_ENV_VENV_NAME; or echo ".venv")
                set -l created_venv_path "$project_dir/$venv_dir"
                if test -f "$created_venv_path/bin/activate.fish"
                    source "$created_venv_path/bin/activate.fish"
                    set -gx _AUTO_UV_ENV_ACTIVATION_DIR "$project_dir"
                    if set -l python_full_version (python --version 2>&1)
                        set -l python_version (string replace "Python " "" "$python_full_version")
                        if test "$AUTO_UV_ENV_QUIET" != "1"
                            echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $python_version)"
                        end
                        set -gx AUTO_UV_ENV_PYTHON_VERSION "$python_version"
                    else
                        if test "$AUTO_UV_ENV_QUIET" != "1"
                            echo -e "\033[0;32m🚀\033[0m UV environment activated (Python not installed)"
                            echo -e "\033[0;34mℹ️\033[0m  Run 'uv python install' to install Python"
                        end
                        set -gx AUTO_UV_ENV_PYTHON_VERSION "unknown"
                    end
                end
            end

            # Handle activation
            if test -n "$activate_path" -a -f "$activate_path/bin/activate.fish"
                source "$activate_path/bin/activate.fish"
                # Track where we activated from
                set -gx _AUTO_UV_ENV_ACTIVATION_DIR (_auto_uv_env_project_from_venv_path "$activate_path")
                # Use fish string manipulation instead of cut for performance
                # Handle case where python might not be available yet in UV environments
                if set -l python_full_version (python --version 2>&1)
                    set -l python_version (string replace "Python " "" "$python_full_version")
                    if test "$AUTO_UV_ENV_QUIET" != "1"
                        echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $python_version)"
                    end
                    set -gx AUTO_UV_ENV_PYTHON_VERSION $python_version
                else
                    if test "$AUTO_UV_ENV_QUIET" != "1"
                        echo -e "\033[0;32m🚀\033[0m UV environment activated (Python not installed)"
                        echo -e "\033[0;34mℹ️\033[0m  Run 'uv python install' to install Python"
                    end
                    set -gx AUTO_UV_ENV_PYTHON_VERSION "unknown"
                end
            else if test -n "$activate_path" -a -f "$activate_path/pyvenv.cfg"
                # Fish-specific activation when activate.fish doesn't exist
                set -gx VIRTUAL_ENV $activate_path
                set -gx _OLD_VIRTUAL_PATH $PATH
                set -gx PATH "$activate_path/bin" $PATH
                # Track where we activated from
                set -gx _AUTO_UV_ENV_ACTIVATION_DIR (_auto_uv_env_project_from_venv_path "$activate_path")
                # Use fish string manipulation instead of cut for performance
                # Handle case where python might not be available yet in UV environments
                if set -l python_full_version (python --version 2>&1)
                    set -l python_version (string replace "Python " "" "$python_full_version")
                    if test "$AUTO_UV_ENV_QUIET" != "1"
                        echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $python_version)"
                    end
                    set -gx AUTO_UV_ENV_PYTHON_VERSION $python_version
                else
                    if test "$AUTO_UV_ENV_QUIET" != "1"
                        echo -e "\033[0;32m🚀\033[0m UV environment activated (Python not installed)"
                        echo -e "\033[0;34mℹ️\033[0m  Run 'uv python install' to install Python"
                    end
                    set -gx AUTO_UV_ENV_PYTHON_VERSION "unknown"
                end
            end
        end
    end

    # Hook into directory changes
    function __auto_uv_env_on_pwd --on-variable PWD
        auto_uv_env
    end

    # Lazy loading: check on startup only if we're already in a managed project tree.
    set -l _auto_uv_env_startup_project_dir (_auto_uv_env_find_project_dir)
    if test $status -eq 0; and test -n "$_auto_uv_env_startup_project_dir"
        auto_uv_env
    end
else
    # Helpful message if auto-uv-env is not installed
    function auto_uv_env
        if test -f "pyproject.toml"
            echo "auto-uv-env not found. Install with: brew install ashwch/tap/auto-uv-env" >&2
        end
    end
end
