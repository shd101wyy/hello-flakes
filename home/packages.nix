{ pkgs }:
let
  packages = with pkgs; [
    # Apps
    age # Modern encryption tool with small explicit keys
    awscli2
    bind
    browsh # fully-modern text-based browser
    cargo
    gcc
    gh # GitHub CLI tool
    gnumake
    htop
    hub # Command-line wrapper for git that makes you better at GitHub
    jdk
    jq # A lightweight and flexible command-line JSON processor
    lsof
    lzip
    netcat # `nc` command
    nodejs
    pandoc
    poetry
    # python3 # <= Cause conflicts with below
    (python3.withPackages (ps: with ps; 
      [ pip
         ansible
         virtualenv
         black
         isort 
         pylint
          ]
         )
    )
    ruby
    rustc
    sops # Mozilla sops (Secrets OPerationS) is an editor of encrypted files
    sqlite
    sshpass
    tmux
    tree
    unzip
    wget
    xsel
    yarn
    zip

    # Nix related
    niv
    nix-prefetch
    nixpkgs-fmt
    nil
    direnv
    nix-direnv

  ];
in
packages
