{ config, pkgs, ... }:

{
  home.homeDirectory = "/home/jon.gao";

  custom.databricks.enable = true;
}
