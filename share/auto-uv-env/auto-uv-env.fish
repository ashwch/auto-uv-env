# auto-uv-env.fish - Fish integration for auto-uv-env
# https://github.com/ashwch/auto-uv-env
#
# Add this to your ~/.config/fish/config.fish:
#   source (brew --prefix)/share/auto-uv-env/auto-uv-env.fish

# Only set up if auto-uv-env is available
if command -v auto-uv-env >/dev/null 2>&1
    # Function to check and activate UV environments
    function auto_uv_env
        set -l state_file "/tmp/auto-uv-env."(echo %self)".state"

        # Get state from auto-uv-env
        if not auto-uv-env --check-safe $PWD > /dev/null 2>&1
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
                if test "$AUTO_UV_ENV_QUIET" != "1"
                    set -l python_version (python --version 2>&1 | cut -d' ' -f2)
                    echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $python_version)"
                end
            else if test -n "$activate_path" -a -f "$activate_path/pyvenv.cfg"
                # Fish-specific activation when activate.fish doesn't exist
                set -gx VIRTUAL_ENV $activate_path
                set -gx _OLD_VIRTUAL_PATH $PATH
                set -gx PATH "$activate_path/bin" $PATH
                if test "$AUTO_UV_ENV_QUIET" != "1"
                    set -l python_version (python --version 2>&1 | cut -d' ' -f2)
                    echo -e "\033[0;32m🚀\033[0m UV environment activated (Python $python_version)"
                end
            end
        end
    end

    # Hook into directory changes
    function __auto_uv_env_on_pwd --on-variable PWD
        auto_uv_env
    end

    # Run on shell startup
    auto_uv_env
else
    # Helpful message if auto-uv-env is not installed
    function auto_uv_env
        if test -f "pyproject.toml"
            echo "auto-uv-env not found. Install with: brew install ashwch/tap/auto-uv-env" >&2
        end
    end
end
