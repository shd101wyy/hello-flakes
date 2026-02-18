# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # include NixOS-WSL modules
    # <nixos-wsl/modules>
    # ^ This is done in flake.nix
  ];

  wsl.enable = true;
  wsl.defaultUser = "yiyiwang";
  
  # wsl.docker-desktop.enable = true; # Enable Windows Docker Desktop integration.
  # NOTE: Let's use the native docker, not docker desktop on windows for now.

  users.users.yiyiwang = {
    isNormalUser = true;
    extraGroups = [
      "wheel" # Enable 'sudo' for the user;
      "docker" # Adding users to the `docker` group will provide them access to the socket:
    ];
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Enable foreign binaries to run on NixOS
  programs.nix-ld.enable = true;

  # Set my time zone
  time.timeZone = "Asia/Shanghai";

  # Enable the X11 windowing system
  services.xserver.enable = true;

  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

  # Environment variables
  environment.variables.EDITOR = "nvim";

  # Enable ZSH
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  # Hack to set /etc/shells as not symbolic link
  # We need to do this because the `flatpak run` cannot mount the symbolic link
  environment.etc.shells.mode = "0666";
  # https://github.com/NixOS/nixpkgs/issues/189851
  # https://discourse.nixos.org/t/open-links-from-flatpak-via-host-firefox/15465/8
  systemd.user.extraConfig = ''
    DefaultEnvironment="PATH=/run/current-system/sw/bin"
  '';

  # Enable xdg related
  xdg.portal.extraPortals = with pkgs; [
    # xdg-desktop-portal-kde
    xdg-desktop-portal-gtk
  ];
  xdg.portal.enable = true;
  xdg.portal.config.common.default = [ "gtk" ];

  # Enable SSH
  services.openssh.enable = true;

  fonts = {
    fontDir.enable = true;
    enableDefaultPackages = true;
    packages = with pkgs; [
      hack-font
      jetbrains-mono
      # (nerdfonts.override {
      #   fonts = [
      #     "FiraCode"
      #     "DroidSansMono"
      #     "Ubuntu"
      #     "UbuntuMono"
      #   ];
      # })
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      sarasa-gothic # 更纱黑体
      source-code-pro
      ubuntu-classic
    ];
    fontconfig = {
      # 测试字体 👹
      defaultFonts = {
        emoji = [ "Noto Color Emoji" ];
        serif = [ "Ubuntu Regular" ];
        sansSerif = [ "Sans Regular" ];
        monospace = [ "Ubuntu Mono Regular" ];
      };
      antialias = true;
      hinting.enable = true;
      # hinting.style = "slight";
    };
  };

  # Virtualization
  virtualisation = {
    # https://nixos.wiki/wiki/WayDroid
    # Run the following to init:
    # $ sudo waydroid init -c https://waydroid.bardia.tech/OTA/system -v https://waydroid.bardia.tech/OTA/vendor
    # After intalling:
    # $ sudo systemctl start waydroid-container
    # $ waydroid show-full-ui
    ## waydroid = {
    ##   enable = true;
    ## };
    
    docker = {
      enable = true;
      daemon.settings = {
        userland-proxy = false;
        # experimental = true;
        # ipv6 = true;
        registry-mirrors = [
          # 国内 dockerhub 镜像 https://blog.csdn.net/buluxianfeng/article/details/143977194
          # "https://docker.unsee.tech"
          # "https://dockerpull.org"
          # "https://dockerhub.icu"
          # "https://hub.rat.dev"
          # "https://hub.xdark.top"
          # "https://hub.littlediary.cn"
          "https://docker.1ms.run"
        ];
        "proxies" = {
          "http-proxy" = "http://127.0.0.1:8889";
          "https-proxy" = "http://127.0.0.1:8889";
        };
      };
    };
    # lxd = { enable = true; };
  };

  nix.settings = {
    auto-optimise-store = true;
    substituters = lib.mkForce [
      # BROKEN: "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" # <- This is very slow
      "https://cache.nixos.org"
    ];
    allowed-users = [
      "*"
      "@users"
    ];
    trusted-users = [ "@wheel" ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
