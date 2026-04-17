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

  # System-level defaults
  system.stateVersion = 5;
}
