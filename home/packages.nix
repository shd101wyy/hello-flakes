{ pkgs }:
let
  packages = with pkgs; [
    sops # Mozilla sops (Secrets OPerationS) is an editor of encrypted files
    age # Modern encryption tool with small explicit keys
    jq # A lightweight and flexible command-line JSON processor
    hub # Command-line wrapper for git that makes you better at GitHub
  ];
in packages
