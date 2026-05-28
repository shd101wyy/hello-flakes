{ pkgs, pkgsUnstable, ... }:
# This is the home configuration for yiyiwang's steam deck
# It seems like not all home.packages are working well, so I decided to install all applications by the `Discover` app on SteamOS instead of using Nix
{
  home.stateVersion = "22.11";
  home.username = "deck";
  home.homeDirectory = "/home/deck";

  manual.manpages.enable = false;

  # The `deck` user's login shell is bash, so the zsh ~/.zprofile hook in
  # common.nix never runs here. SteamOS updates reset the read-only root and
  # wipe Nix's hook in /etc/profile.d; ~/.bash_profile lives on the persistent
  # /home partition, so sourcing the daemon here survives updates.
  # (This only restores `nix` on PATH. If /nix itself is empty after an update,
  # the bind-mount/systemd units are gone instead — re-run the Determinate
  # installer: https://determinate.systems/posts/nix-on-the-steam-deck )
  programs.bash = {
    enable = true;
    profileExtra = ''
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
    '';
  };

  home.packages = with pkgs;
    [
      # hello # Hello, world

      ## gnome.gnome-terminal # <- Doesn't work

      # VPN
      # qv2ray # Not working well
      # clash-verge # Please download from https://github.com/zzzgydi/clash-verge/releases/

      # Tools/Apps
      # pandoc
      flatpak-xdg-utils
    ] ++ (import ./packages.nix {
      pkgs = pkgs;
      pkgsUnstable = pkgsUnstable;
    });
}
