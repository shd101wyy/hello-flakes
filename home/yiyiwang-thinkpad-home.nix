{ pkgs, ... }:
# This module is managed by Flakes
# Run the following commands build the configuration:
# $ nix build .\#homeConfigurations.yiyiwang-thinkpad-home.activationPackage
# $ "$(nix path-info .\#homeConfigurations.yiyiwang-thinkpad-home.activationPackage)"/activate 
# To get the SHA256
# nix-prefetch fetchFromGitHub --owner owner --repo repo --rev 65bb66d364e0d10d00bd848a3d35e2755654655b
{
  home.stateVersion = "22.05";
  home.username = "yiyiwang";
  home.homeDirectory = "/home/yiyiwang";

  manual.manpages.enable = false;

  dconf.settings = {
    "org/gnome/mutter" = {
      experimental-features = [ "scale-monitor-framebuffer" ];
    };
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhsWithPackages (ps: with ps; [ rustup zlib glibc ]);
  };


  home.packages = with pkgs; [
    sl # An funny command
    crawl # Dungeon crawl stone soup
  ];
}
