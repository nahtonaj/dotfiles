{ config, pkgs, lib, windowManager, ... }:

# System-level window manager toggle.
# The flake sets `windowManager` to "aerospace" or "yabai". Only the selected
# backend's packages and launchd agents are provisioned, so only one runs.
#
# The chosen backend is also written to /etc/window-manager-backend so
# sketchybar (and any other consumer) can dispatch without needing to
# inspect running processes.

let
  isAerospace = windowManager == "aerospace";
  isYabai = windowManager == "yabai";
in

assert lib.assertMsg (isAerospace || isYabai)
  "windowManager must be \"aerospace\" or \"yabai\", got \"${windowManager}\"";

{
  environment.systemPackages =
    lib.optionals isAerospace [ pkgs.aerospace ]
    ++ lib.optionals isYabai [ pkgs.yabai pkgs.skhd pkgs.jq ];

  # Expose the active backend to userland (e.g. sketchybar).
  environment.etc."window-manager-backend".text = "${windowManager}\n";

  # Aerospace self-registers its own LaunchAgent when start-at-login=true in
  # the TOML. We disable that and manage the agent here so switching backends
  # via darwin-rebuild actually stops/starts the process.
  launchd.user.agents.aerospace = lib.mkIf isAerospace {
    serviceConfig = {
      ProgramArguments = [ "${pkgs.aerospace}/bin/aerospace" ];
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
      StandardOutPath = "/tmp/aerospace.out.log";
      StandardErrorPath = "/tmp/aerospace.err.log";
    };
  };

  # PATH for yabai/skhd includes /opt/homebrew/bin so brew-installed tools
  # (notably sketchybar, which yabai signals call) resolve at runtime.
  launchd.user.agents.yabai = lib.mkIf isYabai {
    serviceConfig = {
      ProgramArguments = [ "${pkgs.yabai}/bin/yabai" ];
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
      EnvironmentVariables = {
        PATH = "${pkgs.yabai}/bin:${pkgs.jq}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "/tmp/yabai.out.log";
      StandardErrorPath = "/tmp/yabai.err.log";
    };
  };

  launchd.user.agents.skhd = lib.mkIf isYabai {
    serviceConfig = {
      ProgramArguments = [ "${pkgs.skhd}/bin/skhd" ];
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
      EnvironmentVariables = {
        PATH = "${pkgs.yabai}/bin:${pkgs.jq}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "/tmp/skhd.out.log";
      StandardErrorPath = "/tmp/skhd.err.log";
    };
  };

}
