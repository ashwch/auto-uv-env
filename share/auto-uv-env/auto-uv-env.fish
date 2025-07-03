# auto-uv-env.fish - Fish integration for auto-uv-env
# https://github.com/ashwch/auto-uv-env
#
# Add this to your ~/.config/fish/config.fish:
#   source (brew --prefix)/share/auto-uv-env/auto-uv-env.fish

# Only set up if auto-uv-env is available
if command -v auto-uv-env >/dev/null 2>&1
    # Function to check and activate UV environments
    function auto_uv_env
        eval (auto-uv-env --check $PWD)
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