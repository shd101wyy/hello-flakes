{ pkgs, pkgsUnstable, ... }:
# This is the home configuration for yiyiwang's WSL setup.
# NOTE: home-manager installs zsh but cannot change your login shell.
# On stock Ubuntu WSL (not NixOS-WSL), run these once to switch to zsh:
#   $ echo /home/yiyiwang/.nix-profile/bin/zsh | sudo tee -a /etc/shells
#   $ chsh -s /home/yiyiwang/.nix-profile/bin/zsh
{
  home.stateVersion = "22.11";
  home.username = "yiyiwang";
  home.homeDirectory = "/home/yiyiwang";

  manual.manpages.enable = false;

  home.packages =
    with pkgs;
    [
      devenv # Fast, Declarative, Reproducible, and Composable Developer Environments
      pkgsUnstable.google-chrome
    ]
    ++ (import ./packages.nix {
      pkgs = pkgs;
      pkgsUnstable = pkgsUnstable;
    });
}
