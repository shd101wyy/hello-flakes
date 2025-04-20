{ pkgs, pkgsUnstable, ... }:
# This is the home configuration for yiyiwang's steam deck
# It seems like not all home.packages are working well, so I decided to install all applications by the `Discover` app on SteamOS instead of using Nix
{
  home.stateVersion = "22.11";
  home.username = "deck";
  home.homeDirectory = "/home/deck";

  manual.manpages.enable = false;

  home.packages = with pkgs;
    [
      # hello # Hello, world

      ## gnome.gnome-terminal # <- Doesn't work

      # VPN
      # qv2ray # Not working well
      # clash-verge # Please download from https://github.com/zzzgydi/clash-verge/releases/

      # Tools/Apps
      # pandoc
    ] ++ (import ./packages.nix {
      pkgs = pkgs;
      pkgsUnstable = pkgsUnstable;
    });
}
