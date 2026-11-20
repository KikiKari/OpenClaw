#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "c3fbe1becd7de12614380c54008d991754b794a71ebf6b4a6eafe12b43dc9135", "source_sha256": "4a2907e2ea521dc1e81ebd6e57ee9ab2269d633101a5fe398c3b55dfc0d99040", "target_language": "shell"}
# install.ps1 — portiert nach shell
# Quelle: powershell, workspace@local:skills/github-clones/openclaw/scripts/install.ps1
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# OpenClaw Installer for Linux/macOS (Bash)
# Usage: curl -fsSL https://openclaw.ai/install.sh | bash
# Or: bash <(curl -fsSL https://openclaw.ai/install.sh) --no-onboard

# Default values
INSTALL_METHOD="npm"
TAG="latest"
GIT_DIR="$HOME/openclaw"
NO_ONBOARD=false
NO_GIT_UPDATE=false
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-method)
            INSTALL_METHOD="$2"
            shift 2
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --git-dir)
            GIT_DIR="$2"
            shift 2
            ;;
        --no-onboard)
            NO_ONBOARD=true
            shift
            ;;
        --no-git-update)
            NO_GIT_UPDATE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors
ACCENT="\033[38;2;255;77;77m"    # coral-bright
SUCCESS="\033[38;2;0;229;204m"   # cyan-bright
WARN="\033[38;2;255;176;32m"     # amber
ERROR="\033[38;2;230;57;70m"     # coral-mid
MUTED="\033[38;2;90;100;128m"    # text-muted
NC="\033[0m"                     # No Color

write_host() {
    local message="$1"
    local level="${2:-info}"
    
    case "$level" in
        success) echo -e "${SUCCESS}✓${NC} $message" ;;
        warn)    echo -e "${WARN}!${NC} $message" ;;
        error)   echo -e "${ERROR}✗${NC} $message" ;;
        *)       echo -e "${MUTED}·${NC} $message" ;;
    esac
}

write_banner() {
    write_host ""
    write_host "${ACCENT}  🦞 OpenClaw Installer${NC}" "info"
    write_host "${MUTED}  All your chats, one OpenClaw.${NC}" "info"
    write_host ""
}

get_node_version() {
    if command -v node >/dev/null 2>&1; then
        node --version 2>/dev/null | sed 's/^v//' || true
    fi
}

get_npm_version() {
    if command -v npm >/dev/null 2>&1; then
        npm --version 2>/dev/null || true
    fi
}

install_node() {
    write_host "Node.js not found" "info"
    write_host "Installing Node.js..." "info"
    
    # Try package managers based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew >/dev/null 2>&1; then
            write_host "  Using Homebrew..." "info"
            if [ "$DRY_RUN" = false ]; then
                brew install node 2>&1 || {
                    write_host "  Homebrew install failed" "warn"
                    return 1
                }
            fi
            write_host "  Node.js installed via Homebrew" "success"
            return 0
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get >/dev/null 2>&1; then
            write_host "  Using apt..." "info"
            if [ "$DRY_RUN" = false ]; then
                sudo apt-get update && sudo apt-get install -y nodejs npm 2>&1 || {
                    write_host "  apt install failed" "warn"
                    return 1
                }
            fi
            write_host "  Node.js installed via apt" "success"
            return 0
        elif command -v yum >/dev/null 2>&1; then
            write_host "  Using yum..." "info"
            if [ "$DRY_RUN" = false ]; then
                sudo yum install -y nodejs npm 2>&1 || {
                    write_host "  yum install failed" "warn"
                    return 1
                }
            fi
            write_host "  Node.js installed via yum" "success"
            return 0
        elif command -v dnf >/dev/null 2>&1; then
            write_host "  Using dnf..." "info"
            if [ "$DRY_RUN" = false ]; then
                sudo dnf install -y nodejs npm 2>&1 || {
                    write_host "  dnf install failed" "warn"
                    return 1
                }
            fi
            write_host "  Node.js installed via dnf" "success"
            return 0
        elif command -v pacman >/dev/null 2>&1; then
            write_host "  Using pacman..." "info"
            if [ "$DRY_RUN" = false ]; then
                sudo pacman -S --noconfirm nodejs npm 2>&1 || {
                    write_host "  pacman install failed" "warn"
                    return 1
                }
            fi
            write_host "  Node.js installed via pacman" "success"
            return 0
        fi
    fi
    
    write_host "Could not install Node.js automatically" "error"
    write_host "Please install Node.js 22+ manually from: https://nodejs.org" "info"
    return 1
}

ensure_node() {
    local node_version=$(get_node_version)
    if [ -n "$node_version" ]; then
        local major=$(echo "$node_version" | cut -d. -f1)
        if [ "$major" -ge 22 ]; then
            write_host "Node.js v$node_version found" "success"
            return 0
        else
            write_host "Node.js v$node_version found, but need v22+" "warn"
        fi
    fi
    install_node
}

get_git_version() {
    if command -v git >/dev/null 2>&1; then
        git --version 2>/dev/null || true
    fi
}

install_git() {
    write_host "Git not found" "info"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew >/dev/null 2>&1; then
            write_host "  Installing Git via Homebrew..." "info"
            if [ "$DRY_RUN" = false ]; then
                brew install git 2>&1 || {
                    write_host "  Homebrew install failed" "warn"
                    return 1
                }
            fi
            write_host "  Git installed" "success"
            return 0
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get >/dev/null 2>&1; then
            write_host "  Installing Git via apt..." "info"
            if [ "$DRY_RUN" = false ]; then
                sudo apt-get update && sudo apt-get install -y git 2>&1 || {
                    write_host "  apt install failed" "warn"
                    return 1
                }
            fi
            write_host "  Git installed" "success"
            return 0
        elif command -v yum >/dev/null 2>&1; then
            write_host "  Installing Git via yum..." "info"
            if [ "$DRY_RUN" = false ]; then
                sudo yum install -y git 2>&1 || {
                    write_host "  yum install failed" "warn"
                    return 1
                }
            fi
            write_host "  Git installed" "success"
            return 0
        elif command -v dnf >/dev/null 2>&1; then
            write_host "  Installing Git via dnf..." "info"
            if [ "$DRY_RUN" = false ]; then
                sudo dnf install -y git 2>&1 || {
                    write_host "  dnf install failed" "warn"
                    return 1
                }
            fi
            write_host "  Git installed" "success"
            return 0
        elif command -v pacman >/dev/null 2>&1; then
            write_host "  Installing Git via pacman..." "info"
            if [ "$DRY_RUN" = false ]; then
                sudo pacman -S --noconfirm git 2>&1 || {
                    write_host "  pacman install failed" "warn"
                    return 1
                }
            fi
            write_host "  Git installed" "success"
            return 0
        fi
    fi
    
    write_host "Please install Git manually" "error"
    return 1
}

ensure_git() {
    local git_version=$(get_git_version)
    if [ -n "$git_version" ]; then
        write_host "$git_version found" "success"
        return 0
    fi
    install_git
}

install_openclaw_npm() {
    local target="${1:-latest}"
    local install_spec=$(resolve_package_install_spec "$target")
    
    write_host "Installing OpenClaw ($install_spec)..." "info"
    
    if [ "$DRY_RUN" = false ]; then
        npm install -g "$install_spec" --no-fund --no-audit 2>&1 || {
            write_host "npm install failed" "error"
            return 1
        }
    fi
    
    write_host "OpenClaw installed" "success"
    return 0
}

install_openclaw_git() {
    local repo_dir="$1"
    local update="${2:-true}"
    
    write_host "Installing OpenClaw from git..." "info"
    
    if [ ! -d "$repo_dir" ]; then
        write_host "  Cloning repository..." "info"
        if [ "$DRY_RUN" = false ]; then
            git clone https://github.com/openclaw/openclaw.git "$repo_dir" 2>&1 || return 1
        fi
    elif [ "$update" = true ] && [ "$DRY_RUN" = false ]; then
        write_host "  Updating repository..." "info"
        git -C "$repo_dir" pull --rebase 2>&1 || return 1
    fi
    
    # Install pnpm if not present
    if ! command -v pnpm >/dev/null 2>&1; then
        write_host "  Installing pnpm..." "info"
        if [ "$DRY_RUN" = false ]; then
            npm install -g pnpm 2>&1 || return 1
        fi
    fi
    
    # Install dependencies
    write_host "  Installing dependencies..." "info"
    if [ "$DRY_RUN" = false ]; then
        pnpm install --dir "$repo_dir" 2>&1 || return 1
    fi
    
    # Build
    write_host "  Building..." "info"
    if [ "$DRY_RUN" = false ]; then
        pnpm --dir "$repo_dir" build 2>&1 || return 1
    fi
    
    # Create wrapper
    local wrapper_dir="$HOME/.local/bin"
    mkdir -p "$wrapper_dir"
    
    if [ "$DRY_RUN" = false ]; then
        cat > "$wrapper_dir/openclaw" << 'EOF'
#!/bin/bash
node "$(dirname "$0")/../openclaw/dist/entry.js" "$@"
EOF
        chmod +x "$wrapper_dir/openclaw"
    fi
    
    write_host "OpenClaw installed" "success"
    return 0
}

test_explicit_package_install_spec() {
    local target="$1"
    
    if [ -z "$target" ]; then
        return 1
    fi
    
    case "$target" in
        *://*|*#*|file:*|github:*|git+ssh:*|git+https:*|git+http:*|git+file:*|npm:*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

resolve_package_install_spec() {
    local target="${1:-latest}"
    local trimmed=$(echo "$target" | xargs)
    
    if [ -z "$trimmed" ]; then
        echo "openclaw@latest"
        return
    fi
    
    if [ "$(echo "$trimmed" | tr '[:upper:]' '[:lower:]')" = "main" ]; then
        echo "github:openclaw/openclaw#main"
        return
    fi
    
    if test_explicit_package_install_spec "$trimmed"; then
        echo "$trimmed"
        return
    fi
    
    echo "openclaw@$trimmed"
}

add_to_path() {
    local path_to_add="$1"
    
    # Check if already in PATH
    if [[ ":$PATH:" != *":$path_to_add:"* ]]; then
        # Add to shell profile files
        local profile_files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
        local added=false
        
        for profile in "${profile_files[@]}"; do
            if [ -f "$profile" ]; then
                if ! grep -q "export PATH=.*$path_to_add" "$profile" 2>/dev/null; then
                    echo "export PATH=\"\$PATH:$path_to_add\"" >> "$profile"
                    added=true
                fi
            fi
        done
        
        if [ "$added" = true ]; then
            write_host "Added $path_to_add to PATH in shell profiles" "info"
            export PATH="$PATH:$path_to_add"
        fi
    fi
}

main() {
    write_banner
    
    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        write_host "macOS detected" "success"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        write_host "Linux detected" "success"
    else
        write_host "Unsupported OS detected" "warn"
    fi
    
    if ! ensure_node; then
        exit 1
    fi
    
    if [ "$INSTALL_METHOD" = "git" ]; then
        if ! ensure_git; then
            exit 1
        fi
        
        if [ "$DRY_RUN" = true ]; then
            write_host "[DRY RUN] Would install OpenClaw from git to $GIT_DIR" "info"
        else
            if ! install_openclaw_git "$GIT_DIR" "$(! $NO_GIT_UPDATE)"; then
                exit 1
            fi
        fi
    else
        # npm method
        if ! ensure_git; then
            write_host "Git is required for npm installs. Please install Git and try again." "warn"
        fi
        
        if [ "$DRY_RUN" = true ]; then
            write_host "[DRY RUN] Would install OpenClaw via npm ($(resolve_package_install_spec "$TAG"))" "info"
        else
            if ! install_openclaw_npm "$TAG"; then
                exit 1
            fi
        fi
    fi
    
    # Try to add npm global bin to PATH
    if command -v npm >/dev/null 2>&1; then
        local npm_prefix
        npm_prefix=$(npm config get prefix 2>/dev/null) || true
        if [ -n "$npm_prefix" ]; then
            add_to_path "$npm_prefix/bin"
        fi
    fi
    
    if [ "$NO_ONBOARD" = false ] && [ "$DRY_RUN" = false ]; then
        write_host ""
        write_host "Run 'openclaw onboard' to complete setup" "info"
    fi
    
    write_host ""
    write_host "🦞 OpenClaw installed successfully!" "success"
}

main
