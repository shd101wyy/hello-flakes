{ pkgs, ... }:
# This is the home configuration for yiyiwang's steam deck
{
  home.stateVersion = "22.11";
  home.username = "deck";
  home.homeDirectory = "/home/deck";
  home.packages = with pkgs; [
    hello # Hello, world
    
    # Software development
    nodejs-16_x

    # System
    netcat # `nc` command

    # V2ray
    qv2ray

    # Browser
    google-chrome

    # Nix related
    nixfmt
    niv
    direnv
  ];
}
