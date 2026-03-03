#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Nix Flake + Home Manager Bootstrap Script
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Dotfiles Bootstrap ==="
echo "Dotfiles directory: $DOTFILES_DIR"
echo ""

# -----------------------------------------------------------------------------
# 1. Detect platform
# -----------------------------------------------------------------------------
OS="$(uname -s)"
case "$OS" in
  Linux)  PLATFORM="linux" ;;
  Darwin) PLATFORM="darwin" ;;
  *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac
echo "Platform: $PLATFORM"

# -----------------------------------------------------------------------------
# 2. Install Nix (if not present)
# -----------------------------------------------------------------------------
if ! command -v nix &> /dev/null; then
  echo ""
  echo "Installing Nix (single-user, no daemon)..."
  sh <(curl -L https://nixos.org/nix/install) --no-daemon --no-channel-add
  echo ""
  echo "Nix installed. Sourcing environment..."
  # Source nix for this session (single-user install)
  if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
else
  echo "Nix already installed: $(nix --version)"
fi

# -----------------------------------------------------------------------------
# 3. Enable flakes (if not already)
# -----------------------------------------------------------------------------
NIX_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"
if ! grep -q "experimental-features.*flakes" "$NIX_CONF" 2>/dev/null && \
   ! grep -q "experimental-features.*flakes" /etc/nix/nix.conf 2>/dev/null; then
  echo "Enabling flakes..."
  mkdir -p "$(dirname "$NIX_CONF")"
  echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
fi

# -----------------------------------------------------------------------------
# 4. Init git submodules (NormalNvim)
# -----------------------------------------------------------------------------
echo ""
echo "Initializing git submodules..."
cd "$DOTFILES_DIR"
git submodule update --init --recursive

# -----------------------------------------------------------------------------
# 5. Apply configuration
# -----------------------------------------------------------------------------
echo ""
if [ "$PLATFORM" = "linux" ]; then
  echo "Applying home-manager configuration for Linux..."
  nix run home-manager -- switch --flake "$DOTFILES_DIR#jon.gao@linux"
elif [ "$PLATFORM" = "darwin" ]; then
  echo "Applying nix-darwin configuration for macOS..."
  # Build and activate nix-darwin (includes home-manager)
  nix run nix-darwin -- switch --flake "$DOTFILES_DIR#jon.gao-mac"
fi

# -----------------------------------------------------------------------------
# 6. Install TPM plugins
# -----------------------------------------------------------------------------
echo ""
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Installing tmux plugins via TPM..."
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
else
  echo "TPM not found — it will be cloned on first home-manager activation."
fi

# -----------------------------------------------------------------------------
# 7. Done
# -----------------------------------------------------------------------------
echo ""
echo "=== Bootstrap complete! ==="
echo ""
echo "Next steps:"
echo "  1. Open a new terminal (or 'exec zsh') to load the new shell config"
echo "  2. Run 'tmux' and press 'prefix + I' to install tmux plugins"
echo "  3. Run 'nvim' to let lazy.nvim sync plugins"
echo ""
