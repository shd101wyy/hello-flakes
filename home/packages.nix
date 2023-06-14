{ pkgs }:
let
  packages = with pkgs; [
    sops # Mozilla sops (Secrets OPerationS) is an editor of encrypted files
    age # Modern encryption tool with small explicit keys
  ];
in packages
