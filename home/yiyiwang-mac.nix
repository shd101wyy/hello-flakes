{ pkgs, pkgsUnstable, ... }:
# This is the home configuration for yiyiwang's steam deck
# It seems like not all home.packages are working well, so I decided to install all applications by the `Discover` app on SteamOS instead of using Nix
{
  home.stateVersion = "22.11";
  home.username = "yiyiwang";
  home.homeDirectory = "/Users/yiyiwang";

  manual.manpages.enable = false;

  home.packages = with pkgs;
    [
      nodejs
      ripgrep
    ];
}
