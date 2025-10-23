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
    flex # Fast lexical analyser generator
    bison # Yacc-compatible parser generator
    go # go language
    gopls # go language server
    golds # Experimental Go local docs server/generator and code reader implemented with some fresh ideas
    gh # GitHub CLI tool
    gnumake
    zenity
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
    pkg-config # Tool that allows packages to find out information about other packages (wrapper script)
    uv
    # python3 # <= Cause conflicts with below
    (python3.withPackages (
      ps: with ps; [
        pip
        ansible
        virtualenv
        black
        isort
        pylint
      ]
    ))
    redis
    ruby
    pkgsUnstable.rustc
    scc # Very fast accurate code counter with complexity calculations and COCOMO estimates written in pure Go
    sops # Mozilla sops (Secrets OPerationS) is an editor of encrypted files
    sqlite
    sshpass
    telegram-desktop
    tldr
    tree
    unzip
    wget
    wireguard-tools
    xsel
    yarn
    yazi # File manager
    # yarn-berry
    zip

    # tmux
    zellij # Use zellij to replace tmux

    # zig language
    pkgsUnstable.zig
    pkgsUnstable.zls # zig LSP

    # elixir
    ## elixir_1_18

    # Nix related
    niv
    nix-prefetch
    nixpkgs-fmt
    nil
    direnv
    nix-direnv
    nixfmt-rfc-style
    devenv

    # LaTeX
    texliveFull

    # lisp (scheme)
    chez
    newlisp
    chicken

    # typescript language server
    typescript-language-server

    # Crypto
    # pkgsUnstable.railway-wallet

    # Wechat
    ## pkgsUnstable.wechat-uos

    ngrok # Allows you to expose a web server running on your local machine to the internet
  ];
in
packages
