{ config, pkgs, lib, flakePath, ... }:

{
  options.custom.databricks.enable = lib.mkEnableOption "Databricks work aliases";

  config = lib.mkIf config.custom.databricks.enable {
    # Tool installers that export UV_NO_CONFIG=1 (e.g. the hermes-agent
    # installer) make uv skip ~/.config/uv/uv.toml and fall back to public
    # PyPI, which the corp network blocks. --no-config disables config-file
    # discovery only, NOT env vars, so pinning the Databricks proxy here keeps
    # those installers working. Mirrors the index in ~/.config/uv/uv.toml.
    home.sessionVariables = {
      UV_DEFAULT_INDEX = "https://pypi-proxy.cloud.databricks.com/simple";
      UV_SYSTEM_CERTS = "1";
      PIP_INDEX_URL = "https://pypi-proxy.cloud.databricks.com/simple";
    };

    programs.zsh.initContent = ''
      # Source work aliases (Databricks/Amazon)
      [ -f "${config.home.homeDirectory}/dotfiles/configs/aliasrc" ] && source "${config.home.homeDirectory}/dotfiles/configs/aliasrc"
    '';
  };
}
