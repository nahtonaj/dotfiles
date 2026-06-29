# Nix profile setup
if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
else if test -e ~/.nix-profile/etc/profile.d/nix.fish
    source ~/.nix-profile/etc/profile.d/nix.fish
end

# Add user-local and Nix binary paths
fish_add_path -g ~/.nix-profile/bin /nix/var/nix/profiles/default/bin
