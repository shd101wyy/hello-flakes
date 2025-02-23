{ pkgs, pkgsUnstable }:
let
  packages = with pkgs; [
    # Apps
    age # Modern encryption tool with small explicit keys
    awscli2
    bind
    browsh # fully-modern text-based browser
    cargo
    docker-compose
    gh # GitHub CLI tool
    gnumake
    gnome.zenity
    helix
    htop
    hub # Command-line wrapper for git that makes you better at GitHub
    # ifuse
    imagemagick # Image manipulation tools
    jdk
    jq # A lightweight and flexible command-line JSON processor
    lsof
    lua
    lzip
    mkcert
    netcat # `nc` command
    ngrok # Allows you to expose a web server running on your local machine to the internet
    nodejs
    nss
    nssTools
    # nss_latest
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
    redis
    ruby
    pkgsUnstable.rustc
    sops # Mozilla sops (Secrets OPerationS) is an editor of encrypted files
    sqlite
    sshpass
    telegram-desktop
    tldr
    tmux
    tree
    unzip
    wget
    wireguard-tools
    xsel
    yarn
    # yarn-berry
    zip

    # zig language
    zig
    zls # zig LSP

    # elixir
    elixir_1_18

    # Nix related
    niv
    nix-prefetch
    nixpkgs-fmt
    nil
    direnv
    nix-direnv
    nixfmt-classic

    # LaTeX
    texliveFull

    # Crypto
    # pkgsUnstable.railway-wallet

    # Wechat
    ## pkgsUnstable.wechat-uos

    ngrok # Allows you to expose a web server running on your local machine to the internet
  ];
in
packages
