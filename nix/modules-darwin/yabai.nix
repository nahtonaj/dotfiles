{ config, pkgs, ... }:

{
  # Bidirectional symlinks so edits to yabairc/skhdrc take effect without
  # a rebuild. Both configs stay symlinked regardless of the active backend —
  # the system module gates which services actually run.
  xdg.configFile."yabai".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/.config/yabai";

  xdg.configFile."skhd".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/.config/skhd";
}
