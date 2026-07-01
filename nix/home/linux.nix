{ config, pkgs, ... }:

{
  home.username = "jon.gao";
  home.homeDirectory = "/home/jon.gao";

  custom.databricks.enable = true;
}
