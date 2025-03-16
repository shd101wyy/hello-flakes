{ pkgs, pkgsUnstable, ... }:
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
    package = pkgs.vscode.fhsWithPackages (
      ps: with ps; [
        rustup
        zlib
        glibc
        openssl.dev
        pkg-config
      ]
    );
  };

  home.packages =
    with pkgs;
    [
      sl # An funny command
      crawl # Dungeon crawl stone soup
      # logseq # A note taking app
      # obsidian # A powerful knowledge base that works on top of a local folder of plain text Markdown files
      bleachbit # A program to clean your computer

      pkgsUnstable.google-chrome
      pkgsUnstable.chromium
      # clash-verge-rev
      ghc # haskell
      pkgsUnstable.koka # Koka language compiler and interpreter
      stripe-cli # A command-line tool for Stripe

      # System
      ## etcher
      gparted
      ## pgloader
      qemu
      quickemu # Quickly create and run optimised Windows, macOS and Linux desktop virtual machines
      # quickgui # A Flutter frontend for quickemu
      eyedropper # Color picker

      llvmPackages_14.llvm
      clang
      cmake

      pkgsUnstable.wechat-uos

      # pkgsUnstable.trezor-suite
    ]
    ++ (import ./packages.nix {
      pkgs = pkgs;
      pkgsUnstable = pkgsUnstable;
    });
}
