#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Nix Flake + Home Manager Bootstrap Script
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER="/tmp/.nix-bootstrap-done-$(id -u)"
LOCKFILE="/tmp/.nix-bootstrap-$(id -u).lock"
LOGFILE="$HOME/.nix-bootstrap.log"

# -----------------------------------------------------------------------------
# Concurrency guard (atomic mkdir)
# -----------------------------------------------------------------------------
if ! mkdir "$LOCKFILE" 2>/dev/null; then
  echo "Another bootstrap is already running (lock: $LOCKFILE). Exiting."
  exit 0
fi
trap 'rmdir "$LOCKFILE" 2>/dev/null' EXIT

# -----------------------------------------------------------------------------
# Error trap — log failures
# -----------------------------------------------------------------------------
on_error() {
  echo "Bootstrap FAILED at line $1 — see $LOGFILE" >&2
}
trap 'on_error $LINENO' ERR

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
# 2. Seed ~/.ssh/rc (before Nix exists, so next SSH triggers bootstrap too)
# -----------------------------------------------------------------------------
if [ ! -f "$HOME/.ssh/rc" ]; then
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  cat > "$HOME/.ssh/rc" << 'SSHRC'
#!/bin/bash
MARKER="/tmp/.nix-bootstrap-done-$(id -u)"
DOTFILES="$HOME/dotfiles"
LOGFILE="$HOME/.nix-bootstrap.log"

if [ ! -f "$MARKER" ] && [ -f "$DOTFILES/bootstrap.sh" ]; then
  LOCKFILE="/tmp/.nix-bootstrap-$(id -u).lock"
  if ! mkdir "$LOCKFILE" 2>/dev/null; then
    exit 0
  fi
  trap 'rmdir "$LOCKFILE" 2>/dev/null' EXIT
  bash "$DOTFILES/bootstrap.sh" >> "$LOGFILE" 2>&1
  if [ $? -eq 0 ]; then
    touch "$MARKER"
  fi
fi

# Required: handle X11 forwarding (sshd skips xauth when ~/.ssh/rc exists)
if read proto cookie && [ -n "$DISPLAY" ]; then
  if [ "$(echo $DISPLAY | cut -c1-10)" = 'localhost:' ]; then
    echo "add unix:$(echo $DISPLAY | cut -c11-) $proto $cookie"
  else
    echo "add $DISPLAY $proto $cookie"
  fi | xauth -q -
fi
SSHRC
  chmod 755 "$HOME/.ssh/rc"
  echo "Seeded ~/.ssh/rc for future SSH sessions"
fi

# -----------------------------------------------------------------------------
# 3. Install Nix (if not present)
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
# 4. Enable flakes (if not already)
# -----------------------------------------------------------------------------
NIX_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"
if ! grep -q "experimental-features.*flakes" "$NIX_CONF" 2>/dev/null && \
   ! grep -q "experimental-features.*flakes" /etc/nix/nix.conf 2>/dev/null; then
  echo "Enabling flakes..."
  mkdir -p "$(dirname "$NIX_CONF")"
  echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
fi

# -----------------------------------------------------------------------------
# 5. Init git submodules (NormalNvim)
# -----------------------------------------------------------------------------
echo ""
echo "Initializing git submodules..."
cd "$DOTFILES_DIR"
git submodule update --init --recursive

# -----------------------------------------------------------------------------
# 6. Apply configuration
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
# 7. Enable tmux systemd service
# -----------------------------------------------------------------------------
echo ""
echo "Enabling tmux systemd service..."
systemctl --user daemon-reload
systemctl --user enable tmux.service
systemctl --user start tmux.service || true

# -----------------------------------------------------------------------------
# 8. Install TPM plugins
# -----------------------------------------------------------------------------
echo ""
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Installing tmux plugins via TPM..."
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
else
  echo "TPM not found — it will be cloned on first home-manager activation."
fi

# -----------------------------------------------------------------------------
# 9. Mark bootstrap complete
# -----------------------------------------------------------------------------
touch "$MARKER"

echo ""
echo "=== Bootstrap complete! ==="
echo ""
echo "Next steps:"
echo "  1. Open a new terminal (or 'exec zsh') to load the new shell config"
echo "  2. Run 'tmux' and press 'prefix + I' to install tmux plugins"
echo "  3. Run 'nvim' to let lazy.nvim sync plugins"
echo ""
