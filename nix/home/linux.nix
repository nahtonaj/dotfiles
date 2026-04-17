{ config, pkgs, ... }:

{
  home.homeDirectory = "/home/jon.gao";

  imports = [
    ../modules/ruflo.nix
  ];

  custom.databricks.enable = true;
  custom.claude.injectRufloWorkflow = true;
}
