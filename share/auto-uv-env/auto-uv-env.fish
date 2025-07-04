# auto-uv-env.fish - Fish integration for auto-uv-env
# https://github.com/ashwch/auto-uv-env
#
# Add this to your ~/.config/fish/config.fish:
#   source (brew --prefix)/share/auto-uv-env/auto-uv-env.fish

# State tracking for proper deactivation
set -gx _AUTO_UV_ENV_ACTIVATION_DIR ""

# Only set up if auto-uv-env is available
if command -v auto-uv-env >/dev/null 2>&1
    # Function to check and activate UV environments
    function auto_uv_env
        # Performance optimization: Skip if no pyproject.toml
        if not test -f "pyproject.toml"
            # Handle deactivation if we left a Python project
            if test -n "$VIRTUAL_ENV"; and test -n "$_AUTO_UV_ENV_ACTIVATION_DIR"
                # Only deactivate if we've actually left the project tree
                if not string match -q "$_AUTO_UV_ENV_ACTIVATION_DIR*" "$PWD"
                    # Deactivate and clean up
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

        # Performance optimization: If we're already in the right venv, skip the check
        if test -n "$VIRTUAL_ENV"; and string match -q "$_AUTO_UV_ENV_ACTIVATION_DIR*" "$PWD"
            # We're still in the same project tree with an active venv
            return 0
        end

        # Performance optimization: Batch check for .venv existence
        set -l venv_dir (test -n "$AUTO_UV_ENV_VENV_NAME"; and echo $AUTO_UV_ENV_VENV_NAME; or echo ".venv")
        # Single stat call is faster than separate -d and -f checks
        if test -f "$venv_dir/bin/activate.fish" -a -z "$VIRTUAL_ENV"
            # Venv exists and we're not in any venv, just activate it
            source "$venv_dir/bin/activate.fish"
            set -gx _AUTO_UV_ENV_ACTIVATION_DIR "$PWD"
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
        if not auto-uv-env --check-safe $PWD > $state_file 2>&1
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

                if test -n "$python_version"
                    # Try specific Python version first
                    if not uv python install "$python_version" 2>/dev/null
                        if test "$AUTO_UV_ENV_QUIET" != "1"
                            echo -e "\033[0;34m🐍\033[0m Python $python_version not available, using default"
                        end
                    end
                    if not uv venv --python "$python_version" 2>/dev/null
                        if not uv venv 2>/dev/null
                            echo -e "\033[0;31m❌\033[0m Failed to create virtual environment" >&2
                            return 1
                        end
                    end
                else
                    if not uv venv 2>/dev/null
                        echo -e "\033[0;31m❌\033[0m Failed to create virtual environment" >&2
                        return 1
                    end
                end
                if test "$AUTO_UV_ENV_QUIET" != "1"
                    echo -e "\033[0;32m✅\033[0m Virtual environment created"
                end
            end

            # Handle activation
            if test -n "$activate_path" -a -f "$activate_path/bin/activate.fish"
                source "$activate_path/bin/activate.fish"
                # Track where we activated from
                set -gx _AUTO_UV_ENV_ACTIVATION_DIR "$PWD"
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
                set -gx _AUTO_UV_ENV_ACTIVATION_DIR "$PWD"
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

    # Lazy loading: Only check on startup if we're already in a Python project
    # This saves ~10ms on shell startup for non-Python directories
    if test -f "pyproject.toml"
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
