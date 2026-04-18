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

  # macOS "Switch to Desktop N" shortcuts (alt+1..0). IDs 118-127 in
  # com.apple.symbolichotkeys. Enabled only in yabai mode; disabled in
  # aerospace mode so aerospace's own alt+N bindings aren't shadowed.
  #
  # Caveat: on macOS 26 (Tahoe), the plist write alone doesn't always
  # register the hotkeys with WindowServer — verified in practice. One-time
  # fix per machine: open System Settings → Keyboard → Keyboard Shortcuts →
  # Mission Control and toggle each "Switch to Desktop N" entry (or just
  # check them if unchecked). After that, the nix-managed enabled=1 value
  # persists correctly. `killall cfprefsd && killall Dock` may also help.
  system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys =
    let
      mkHotkey = char: keycode: {
        enabled = if isYabai then 1 else 0;
        value = {
          parameters = [ char keycode 524288 ];  # 524288 = option/alt
          type = "standard";
        };
      };
    in {
      # Switch to Desktop N: [ ascii-char, keycode, modifier-mask ]
      "118" = mkHotkey 49 18;  # alt+1 → Desktop 1
      "119" = mkHotkey 50 19;  # alt+2 → Desktop 2
      "120" = mkHotkey 51 20;  # alt+3 → Desktop 3
      "121" = mkHotkey 52 21;  # alt+4 → Desktop 4
      "122" = mkHotkey 53 23;  # alt+5 → Desktop 5
      "123" = mkHotkey 54 22;  # alt+6 → Desktop 6
      "124" = mkHotkey 55 26;  # alt+7 → Desktop 7
      "125" = mkHotkey 56 28;  # alt+8 → Desktop 8
      "126" = mkHotkey 57 25;  # alt+9 → Desktop 9
      "127" = mkHotkey 48 29;  # alt+0 → Desktop 10
    };
}
