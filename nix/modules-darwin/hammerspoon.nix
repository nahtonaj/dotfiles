{ config, pkgs, ... }:

{
  # Bidirectional symlink so edits to init.lua take effect after
  # Hammerspoon auto-reloads (pathwatcher wired up in init.lua).
  home.file.".hammerspoon" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/configs/hammerspoon";
    recursive = false;
  };
}
