{ config, pkgs, flakePath, ... }:

{
  home.file.".ideavimrc".source = "${flakePath}/configs/ideavimrc";
}
