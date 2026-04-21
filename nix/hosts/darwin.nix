{ pkgs, ... }:

{
  # Nix & flakes (nix-daemon is managed unconditionally by nix-darwin)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set zsh as default shell system-wide
  programs.zsh.enable = true;

  # Declare user so home-manager can resolve homeDirectory
  users.users."jon.gao" = {
    home = "/Users/jon.gao";
    shell = pkgs.zsh;
  };

  # Required for user-level launchd agents (window manager, etc).
  system.primaryUser = "jon.gao";

  # Let sudo accept TouchID so `nrs` (and any other sudo call) is a tap
  # instead of a typed password.
  security.pam.services.sudo_local.touchIdAuth = true;

  # Allow the primary user to `sudo darwin-rebuild` without a password. The
  # binary path is stable (managed by nix-darwin itself) so this narrow
  # NOPASSWD entry is safe enough for a personal machine.
  security.sudo.extraConfig = ''
    jon.gao ALL=(root) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild
  '';

  # System-level defaults
  system.stateVersion = 5;
}
