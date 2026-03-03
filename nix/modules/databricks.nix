{ config, pkgs, lib, flakePath, ... }:

{
  options.custom.databricks.enable = lib.mkEnableOption "Databricks work aliases";

  config = lib.mkIf config.custom.databricks.enable {
    programs.zsh.initExtra = ''
      # Source work aliases (Databricks/Amazon)
      [ -f "${config.home.homeDirectory}/dotfiles/configs/aliasrc" ] && source "${config.home.homeDirectory}/dotfiles/configs/aliasrc"
    '';
  };
}
