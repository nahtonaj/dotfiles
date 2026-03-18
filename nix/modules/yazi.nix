{ config, pkgs, flakePath, ... }:

{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
  };

  xdg.configFile = {
    "yazi/yazi.toml".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/yazi/yazi.toml";
    "yazi/theme.toml".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/yazi/theme.toml";
    "yazi/package.toml".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/yazi/package.toml";
  };
}
