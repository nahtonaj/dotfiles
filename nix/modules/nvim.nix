{ config, pkgs, normalNvim, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  xdg.configFile."nvim".source = normalNvim;
}
