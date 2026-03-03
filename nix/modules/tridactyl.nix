{ config, pkgs, flakePath, ... }:

{
  home.file.".tridactylrc".source = "${flakePath}/configs/tridactylrc";
}
