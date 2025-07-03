# auto-uv-env.zsh - ZSH integration for auto-uv-env
# https://github.com/ashwch/auto-uv-env
#
# Add this to your ~/.zshrc:
#   source $(brew --prefix)/share/auto-uv-env/auto-uv-env.zsh

# Only set up if auto-uv-env is available
if command -v auto-uv-env >/dev/null 2>&1; then
    # Function to check and activate UV environments
    auto_uv_env() {
        eval "$(auto-uv-env --check "$PWD")"
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