{ pkgs, pkgsUnstable, lib, ... }:
# This is the home configuration for yiyiwang's steam deck
# It seems like not all home.packages are working well, so I decided to install all applications by the `Discover` app on SteamOS instead of using Nix
{
  home.stateVersion = "22.11";
  home.username = "deck";
  home.homeDirectory = "/home/deck";

  manual.manpages.enable = false;

  # The `deck` user's login shell is bash, so the zsh ~/.zprofile hook in
  # common.nix never runs here. SteamOS updates reset the read-only root and
  # wipe Nix's hook in /etc/profile.d; ~/.bash_profile lives on the persistent
  # /home partition, so sourcing the daemon here survives updates.
  # (This only restores `nix` on PATH. If /nix itself is empty after an update,
  # the bind-mount/systemd units are gone instead — re-run the Determinate
  # installer: https://determinate.systems/posts/nix-on-the-steam-deck )
  programs.bash = {
    enable = true;
    profileExtra = ''
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
    '';
    # The deck user's login shell is bash and /etc/passwd is on the read-only
    # rootfs, so `chsh` can't persist. Hand interactive bash sessions off to
    # zsh (installed by programs.zsh in common.nix) so SSH gets a zsh shell.
    # Scripts (`#!/bin/bash`, `ssh deck@deck "cmd"`) still use bash since
    # initExtra only runs for interactive shells.
    initExtra = ''
      if [[ $- == *i* ]] && [ -x "$HOME/.nix-profile/bin/zsh" ]; then
        exec "$HOME/.nix-profile/bin/zsh"
      fi
    '';
  };

  home.packages = with pkgs;
    [
      # hello # Hello, world

      ## gnome.gnome-terminal # <- Doesn't work

      # VPN
      # qv2ray # Not working well
      # clash-verge # Please download from https://github.com/zzzgydi/clash-verge/releases/
      pkgsUnstable.mihomo # Proxy core as headless service, see systemd.user.services.mihomo below

      # Tools/Apps
      # pandoc
      flatpak-xdg-utils
    ] ++ (import ./packages.nix {
      pkgs = pkgs;
      pkgsUnstable = pkgsUnstable;
    });

  # Headless proxy core (Clash Meta / mihomo). Runs as a user service so the
  # proxy is available in game mode and over SSH, not just the KDE session.
  # Requires (once): sudo loginctl enable-linger deck
  # so user services start at boot without any login session.
  # NOTE: stop Clash Verge / disable its auto-launch, it conflicts on port 8889.
  systemd.user.services.mihomo = {
    Unit = {
      Description = "mihomo proxy core (Clash Meta)";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgsUnstable.mihomo}/bin/mihomo -d %h/.config/mihomo";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.startServices = true;

  # CLI helper for the mihomo service (refresh subscription, pick node, ...).
  # See README.md "Mihomo on Steam Deck" and mihomo.sh --help in this repo.
  home.file.".local/bin/mihomo" = {
    source = ../mihomo.sh;
    executable = true;
  };

  # Auto-refresh the subscription when every node is dead (checked every 15min).
  systemd.user.services.mihomo-refresh = {
    Unit = { Description = "Refresh mihomo subscription when all nodes dead"; };
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/mihomo refresh-if-dead";
    };
  };
  systemd.user.timers.mihomo-refresh = {
    Unit = { Description = "Periodic mihomo dead-node refresh check"; };
    Timer = {
      OnBootSec = "10min";
      OnUnitActiveSec = "15min";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # The subscription URL is private, so it is NOT committed to this repo.
  # Keep it in ~/.config/mihomo/sub-url (chmod 600); the activation hook
  # below injects it into the template at ~/.config/mihomo/config.yaml.
  # force = true: the activation hook replaces the linked template with a
  # chmod-600 regular file, so re-activation would otherwise refuse to link.
  home.file.".config/mihomo/config.yaml" = {
    force = true;
    text = ''
    mixed-port: 8889
    allow-lan: false
    mode: rule
    log-level: info
    ipv6: false
    unified-delay: true
    tcp-concurrent: true

    external-controller: 127.0.0.1:9090

    proxy-providers:
      jms:
        type: http
        url: "__SUBSCRIPTION_URL__"
        interval: 86400
        path: ./providers/jms.yaml
        health-check:
          enable: true
          url: "https://www.gstatic.com/generate_204"
          interval: 300

    proxy-groups:
      - name: "PROXY"
        type: select
        proxies:
          - "AUTO"
          - DIRECT
        use:
          - jms
      - name: "AUTO"
        type: url-test
        url: "https://www.gstatic.com/generate_204"
        interval: 300
        use:
          - jms

    rules:
      - "IP-CIDR,192.168.0.0/16,DIRECT,no-resolve"
      - "IP-CIDR,10.0.0.0/8,DIRECT,no-resolve"
      - "IP-CIDR,172.16.0.0/12,DIRECT,no-resolve"
      - "IP-CIDR,100.64.0.0/10,DIRECT,no-resolve"
      - "GEOIP,CN,DIRECT"
      - "MATCH,PROXY"
    '';
  };

  # Inject the private subscription URL after home.file links the template.
  # No-op if ~/.config/mihomo/sub-url is missing (config keeps placeholder).
  home.activation.injectSubscriptionUrl = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -f "$HOME/.config/mihomo/sub-url" ]; then
      ${pkgs.python3}/bin/python3 - "$HOME/.config/mihomo/sub-url" "$HOME/.config/mihomo/config.yaml" <<'PY'
    import os, sys
    url = open(sys.argv[1]).read().strip()
    path = sys.argv[2]
    if os.path.exists(path):
        with open(path) as f:
            data = f.read()
        if "__SUBSCRIPTION_URL__" in data:
            tmp = path + ".tmp"
            with open(tmp, "w") as f:
                f.write(data.replace("__SUBSCRIPTION_URL__", url))
            os.replace(tmp, path)
            os.chmod(path, 0o600)
    PY
    fi
  '';
}
