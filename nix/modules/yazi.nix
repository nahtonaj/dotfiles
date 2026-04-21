{ config, pkgs, flakePath, ... }:

{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
  };

  home.activation.createYaziSymlinks = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.xdg.configHome}/yazi"
    ln -sfn "${config.home.homeDirectory}/dotfiles/.config/yazi/yazi.toml" "${config.xdg.configHome}/yazi/yazi.toml"
    ln -sfn "${config.home.homeDirectory}/dotfiles/.config/yazi/theme.toml" "${config.xdg.configHome}/yazi/theme.toml"
    ln -sfn "${config.home.homeDirectory}/dotfiles/.config/yazi/package.toml" "${config.xdg.configHome}/yazi/package.toml"
  '';
}
