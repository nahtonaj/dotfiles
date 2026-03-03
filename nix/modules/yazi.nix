{ config, pkgs, flakePath, ... }:

{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
  };

  xdg.configFile = {
    "yazi/yazi.toml".source = "${flakePath}/.config/yazi/yazi.toml";
    "yazi/theme.toml".source = "${flakePath}/.config/yazi/theme.toml";
    "yazi/package.toml".source = "${flakePath}/.config/yazi/package.toml";
  };
}
