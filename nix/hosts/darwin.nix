{ pkgs, ... }:

{
  # Nix daemon & flakes
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set zsh as default shell system-wide
  programs.zsh.enable = true;

  # System-level defaults
  system.stateVersion = 5;
}
