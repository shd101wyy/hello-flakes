{ pkgs, lib, ... }:
# Run the following commands:
#  $ sudo ln -s $PWD/my-configuration.nix /etc/nixos/my-configuration.nix
# 
# Then add the code below to /etc/nixos/configuration.nix:
#
#    imports = [
#       ...
#       ./my-configuration.nix
#       ...
#    ]
#
# If `nixos-switch` or `nixos-install` cannot fetch `cache.nixos.org`, then
# add `--option substituters "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"`
#
{
  system = {
    copySystemConfiguration = true;
    stateVersion = "22.05";
  };

  networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true; # Enable wireless support via wpa_supplicant.
  networking.networkmanager.enable =
    true; # Easiest to use and most distros use this by default.

  # Set my time zone
  time.timeZone = "Asia/Shanghai";

  # Enable the X11 windowing system
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  programs.dconf.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound
  sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Packages to install
  environment.systemPackages = with pkgs; [
    # Software development
    git
    vim
    wget
    vscode-fhs
    direnv
    nix-direnv

    # V2ray
    qv2ray
    ## v2ray # Needs to download from 

    # Browser
    google-chrome

    # Nix related
    home-manager
    nixfmt

    # Gnome related
    gnome.gnome-shell
    gnome.gnome-tweaks
    gnome.adwaita-icon-theme
    gnomeExtensions.lunar-calendar
    gnomeExtensions.proxy-switcher
    gnomeExtensions.dash-to-dock
    gnomeExtensions.custom-hot-corners-extended

    # System
    etcher
    gparted

    # Tools
    ## libsForQt514.kolourpaint # Broken
    krita
    gimp
    wpsoffice
    vlc
    anbox
    xournal
    filezilla
    dbeaver

    # Communication
    skypeforlinux
    slack
    tdesktop
    discord
  ];

  # Steam for gaming
  # As downloading steam will cause SSL error in China,
  # after we `sudo su` as root user, we have to run the following to set proxy, eg:
  #   $ export HTTP_PROXY=http://127.0.0.1:8889
  #   $ export HTTPS_PROXY=http://127.0.0.1:8889
  #   $ export http_proxy=http://127.0.0.1:8889
  #   $ export https_proxy=http://127.0.0.1:8889
  # After installation, we have to start Steam from the command line with the proxy env set as well:
  #   $ steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall =
      true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall =
      true; # Open ports in the firewall for Source Dedicated Server
  };

  # Enable ZSH
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Define a user account.
  users.users.yiyiwang = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable 'sudo' for the user;
  };

  # Enable SSH
  services.openssh.enable = true;

  # Enable Chinese input
  i18n = {
    defaultLocale = "en_US.UTF-8"; # "zh_CN.UTF-8";
    inputMethod = {
      enabled = "ibus";
      ibus.engines = with pkgs.ibus-engines; [ libpinyin ];
    };
  };
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      sarasa-gothic # 更纱黑体
      source-code-pro
      hack-font
      jetbrains-mono
    ];
    # fontconfig = {
    #  defaultFonts = {
    #    emoji = [ "Noto Color Emoji" ];
    #    monospace = [ "Noto Sans Mono CJK SC" "DejaVu Sans Mono" ];
    #    sansSerif = [ "Noto Sans CJK SC" "Source Han Sans SC" ];
    #    serif = [ "Noto Serif CJK SC" "Source Han Serif SC" ];
    #  };
    # };
  };

  # Virtualization
  virtualisation = {
    anbox = { enable = true; };
    # docker = { enable = true; };
  };

  # Nix settings
  nix.settings = {
    auto-optimise-store = true;

    substituters = lib.mkForce [
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
    ];

    trusted-users = [ "@wheel" ];

    experimental-features = [ "nix-command" "flakes" ];
  };

  nixpkgs.config = {
    allowUnfree = true;
    # allowBroken = true;
    # allowUnsupportedSystem = true;
    permittedInsecurePackages = [ "electron-12.2.3" ];
  };
}
