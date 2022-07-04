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
  hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Packages to install
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    vscode-fhs

    qv2ray
    v2ray

    google-chrome

    home-manager
    nixfmt
  ];

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Define a user account.
  users.users.yiyiwang = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable 'sudo' for the user;
  };

  # Nix settings
  nix.settings = {
    auto-optimise-store = true;

    substituters = lib.mkForce [
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      # "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      # "https://mirrors.ustc.edu.cn/nix-channels/store"
    ];

    trusted-users = [ "@wheel" ];

    experimental-features = [ "nix-command" "flakes" ];
  };

  nixpkgs.config = {
    allowUnfree = true;
    # allowBroken = true;
    # allowUnsupportedSystem = true;
  };
}
