{ config, lib, pkgs,
# From flake.nix
nur, ... }:
# Run the following command to build the NixOS configuration:
#  $ sudo nixos-rebuild switch --flake '.#yiyiwang-thinkpad'
# 
# If `nixos-switch` or `nixos-install` cannot fetch `cache.nixos.org`, then
# add `--option substituters "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"`
#
# To connect to wifi using command line, run `nmtui`
#
{
  imports = [ # Include the results of the hardware scan
    # This file is generated by `nixos-generate-config --root /mnt`
    # and should be located at `/etc/nixos/hardware-configuration.nix`
    ./hardware-configuration.nix

    # Redis configuration
    ../../services/redis.nix
    # Postgresql configuration
    ../../services/postgresql.nix
    # Neo4j configuration
    ../../services/neo4j.nix
  ];

  # Use the GRUB 2 boot loader
  boot.loader.grub = {
    enable = true;
    version = 2;
    useOSProber = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    # Define on which hard drive you want to install Grub.
    device = "nodev";
    # Only allow maximum 6 boot entries
    configurationLimit = 6;
    # set $FS_UUID to the UUID of the EFI partition
    # Run `sudo blkid` to see the UUID
    # https://nixos.wiki/wiki/Dual_Booting_NixOS_and_Windows
    # https://askubuntu.com/questions/661947/add-windows-10-to-grub-os-list
    # https://askubuntu.com/questions/1271907/dualboot-ubuntu-windows-error-file-efi-microsoft-boot-bootmgfw-efi-not-fou
    ## extraEntries = ''
    ##   menuentry "Windows" {
    ##     insmod part_gpt
    ##     insmod ntfs
    ##     insmod search_fs_uuid
    ##     insmod chain
    ##     search --no-floppy --set=root --fs-uuid e8baa74f-5d51-455c-836f-2ae323c62535
    ##     chainloader /boot/EFI/Windows/Boot/bootmgfw.efi
    ##   }
    ## '';
  };
  boot.loader.efi = {
    efiSysMountPoint = "/boot";
    # canTouchEfiVariables = true;
  };

  system = {
    copySystemConfiguration = false;
    stateVersion = "22.05";
  };

  # networking.hostName = "yiyiwang-thinkpad"; # Define your hostname.
  # Run `sudo nmtui` to activate connection to Wifi
  networking.networkmanager.enable =
    true; # Easiest to use and most distros use this by default.
  networking.enableIPv6 = false; # Disable IPv6

  # Set my time zone
  time.timeZone = "Asia/Shanghai";

  # Enable the X11 windowing system
  services.xserver.enable = true;

  # Intel
  services.xserver.videoDrivers = [ "modesetting" ];

  # Enable the GNOME Desktop Environment
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome = {
    enable = true;
    extraGSettingsOverridePackages = [ pkgs.gnome.mutter ];
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
  };
  programs.dconf.enable = true;

  # https://nixos.wiki/wiki/Xorg
  # Enable HiDPI
  # bigger tty fonts
  hardware.video.hidpi.enable = true;
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
  # services.xserver.dpi = 180;
  environment.variables = {
    # GDK_SCALE = "2";
    # GDK_DPI_SCALE = "0.5";
    _JAVA_OPTIONS = "-Dsun.java2d.uiScale=2";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound
  sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable bluetooth
  hardware.bluetooth.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Environment variables
  environment.variables.EDITOR = "nvim";

  # Packages to install
  environment.systemPackages = with pkgs; [
    # Software development
    git
    wget
    direnv
    nix-direnv
    flatpak
    vim
    tmux
    python3Full
    python310Packages.pip
    python310Packages.ansible
    python310Packages.virtualenv
    nodejs-16_x
    lzip
    sqlite
    cargo
    rustc
    tree

    # V2ray
    qv2ray
    ## v2ray # Needs to download from 

    # Browser
    google-chrome
    firefox

    # Nix related
    nixfmt
    niv
    nix-prefetch

    # Gnome related
    gnome.gnome-shell
    gnome.gnome-tweaks
    gnome.adwaita-icon-theme
    gnomeExtensions.lunar-calendar
    gnomeExtensions.proxy-switcher
    gnomeExtensions.dash-to-dock
    gnomeExtensions.dash-to-panel
    gnomeExtensions.custom-hot-corners-extended
    ## Install Flat Remix GNOME/GDM  https://www.gnome-look.org/p/1013030 
    gnomeExtensions.user-themes

    # System
    etcher
    gparted
    font-manager
    bind
    htop
    zip
    xsel
    ansible
    sshpass

    # Tools/Apps
    ## libsForQt514.kolourpaint # Broken
    ## krita ## Painting tool
    gimp
    vlc
    # wpsoffice
    ## okular
    xournal
    filezilla
    dbeaver
    # peek
    # kooha
    # pgadmin4
    calibre
    foliate
    pandoc
    wkhtmltopdf

    # Java
    # jetbrains.idea-community
    # maven

    # Communication
    skypeforlinux
    slack
    tdesktop
    discord

    # Nur
    pkgs.nur.repos.mic92.hello-nur

    # Gnome app
    evince # document viewer

    # AWS
    awscli2

    # Game engine
    godot
    godot-export-templates
    pixelorama
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
    extraGroups = [
      "wheel" # Enable 'sudo' for the user;
      "docker" # Adding users to the `docker` group will provide them access to the socket:
      "neo4j"
    ];
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
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
    enableDefaultFonts = true;
    fonts = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-emoji
      sarasa-gothic # 更纱黑体
      source-code-pro
      hack-font
      jetbrains-mono
      ubuntu_font_family
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
      hinting.style = "hintslight";
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
    waydroid = { enable = true; };
    docker = { enable = true; };
    lxd = { enable = true; };
  };

  # Nix settings
  nix.settings = {
    # nixPath = [ "nixpkgs=${nixpkgs}" ];
    auto-optimise-store = true;
    substituters = lib.mkForce [
      # BROKEN: "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" # <- This is very slow
      "https://cache.nixos.org"
    ];
    trusted-users = [ "@wheel" ];
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Nixpkgs settings
  nixpkgs.overlays = [ nur.overlay ];
  nixpkgs.config = {
    allowUnfree = true;
    # allowBroken = true;
    # allowUnsupportedSystem = true;
    permittedInsecurePackages = [ "electron-12.2.3" "qtwebkit-5.212.0-alpha4" ];
  };

}
