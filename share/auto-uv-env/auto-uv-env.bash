# auto-uv-env.bash - Bash integration for auto-uv-env
# https://github.com/ashwch/auto-uv-env
#
# Add this to your ~/.bashrc:
#   source $(brew --prefix)/share/auto-uv-env/auto-uv-env.bash

# Only set up if auto-uv-env is available
if command -v auto-uv-env >/dev/null 2>&1; then
    # Function to check and activate UV environments
    auto_uv_env() {
        eval "$(auto-uv-env --check "$PWD")"
    }
    
    # Store the original PROMPT_COMMAND
    _AUTO_UV_ENV_PROMPT_COMMAND_ORIG="${PROMPT_COMMAND:-}"
    
    # Hook into directory changes via PROMPT_COMMAND
    _auto_uv_env_prompt_command() {
        # Run original PROMPT_COMMAND if it exists
        if [[ -n "$_AUTO_UV_ENV_PROMPT_COMMAND_ORIG" ]]; then
            eval "$_AUTO_UV_ENV_PROMPT_COMMAND_ORIG"
        fi
        
        # Check if directory changed
        if [[ "$PWD" != "${_AUTO_UV_ENV_LAST_PWD:-}" ]]; then
            _AUTO_UV_ENV_LAST_PWD="$PWD"
            auto_uv_env
        fi
    }
    
    PROMPT_COMMAND="_auto_uv_env_prompt_command"
    
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