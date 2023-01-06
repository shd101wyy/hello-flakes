{ pkgs, ... }:
# This is the home configuration for yiyiwang's steam deck
# It seems like not all home.packages are working well, so I decided to install all applications by the `Discover` app on SteamOS instead of using Nix
{
  home.stateVersion = "22.11";
  home.username = "deck";
  home.homeDirectory = "/home/deck";

  manual.manpages.enable = false;

  home.packages = with pkgs; [
    hello # Hello, world
    
    # Software development
    nodejs-16_x
    ## gnome.gnome-terminal # <- Doesn't work
    sqlite
    tree

    # System
    netcat # `nc` command

    # V2ray
    qv2ray

    # Nix related
    nixfmt
    niv
    direnv

    # Tools/Apps
    pandoc
  ];
}
