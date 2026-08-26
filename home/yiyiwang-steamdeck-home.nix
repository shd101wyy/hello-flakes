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
      # Wait for real connectivity before starting: at boot mihomo otherwise
      # starts before Wi-Fi/DHCP is up, which makes the subscription fetch and
      # the first health-check round fail (stale provider + all nodes DOWN).
      # www.baidu.com: universal China-friendly DNS probe (must not be a
      # foreign host — e.g. cache.nixos.org is TLS-reset on this network).
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 90); do ip route show default >/dev/null 2>&1 && getent hosts www.baidu.com >/dev/null 2>&1 && exit 0; sleep 2; done; exit 1'";
      ExecStart = "${pkgsUnstable.mihomo}/bin/mihomo -d %h/.config/mihomo";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # DeepSeek Harness Web UI. Runs as a user service for the same reason as
  # mihomo: this machine's /etc/systemd/logind.conf.d/killuserprocesses.conf
  # sets KillUserProcesses=True, so when an SSH session ends, systemd-logind
  # kills EVERY process of that session's scope -- a `dsh-ctl start` launched
  # from SSH dies silently the moment the SSH connection closes (nohup only
  # blocks SIGHUP, not a cgroup kill), and `dsh-ctl status` reports
  # "dsh web: down (port 3080)". As a user service it survives session ends,
  # starts at boot via linger (already enabled), and Restart=on-failure
  # revives it after a crash.
  # NOTE: stop the old instance first (`dsh-ctl stop --port 3080`) or let it
  # die with its SSH session; the service owns port 3080 afterwards.
  systemd.user.services.dsh-web = {
    Unit = {
      Description = "DeepSeek Harness Web UI (dsh web)";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };
    Service = {
      # The dsh-ctl LAN patches are already applied to this install, so
      # --host 0.0.0.0 is allowed and dsh derives the trusted LAN list from
      # the interfaces itself. --no-open: headless, nothing to open.
      ExecStart = "${pkgs.nodejs}/bin/node --expose-internals %h/.local/share/dsh/node_modules/@deepseek-ai/dsh/lib/bin.js web --host 0.0.0.0 --port 3080 --no-open";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.startServices = true;

  # CLI control helper for the mihomo service (refresh subscription, pick node,
  # ...). Named mihomo-ctl so it doesn't shadow the real `mihomo` binary on
  # PATH. See README.md "Mihomo on Steam Deck" and mihomo-ctl.sh in this repo.
  home.file.".local/bin/mihomo-ctl" = {
    source = ../mihomo-ctl.sh;
    executable = true;
  };

  # Auto-refresh the subscription when every node is dead (checked every 15min).
  systemd.user.services.mihomo-refresh = {
    Unit = { Description = "Refresh mihomo subscription when all nodes dead"; };
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/mihomo-ctl refresh-if-dead";
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

  # The subscription URLs are private, so they are NOT committed to this repo.
  # Keep one file per subscription in ~/.config/mihomo/sub-url.d/NAME (chmod
  # 600), where NAME becomes the provider name. The activation hook below
  # generates the proxy-providers section of the template at
  # ~/.config/mihomo/config.yaml from those files.
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

    __PROXY_PROVIDERS__

    proxy-groups:
      - name: "PROXY"
        type: select
        proxies:
          - "AUTO"
          - DIRECT
        use: [__SUBSCRIPTION_NAMES__]
      - name: "AUTO"
        type: url-test
        url: "https://www.gstatic.com/generate_204"
        interval: 300
        use: [__SUBSCRIPTION_NAMES__]

    rules:
      - "IP-CIDR,192.168.0.0/16,DIRECT,no-resolve"
      - "IP-CIDR,10.0.0.0/8,DIRECT,no-resolve"
      - "IP-CIDR,172.16.0.0/12,DIRECT,no-resolve"
      - "IP-CIDR,100.64.0.0/10,DIRECT,no-resolve"
      - "GEOIP,CN,DIRECT"
      - "MATCH,PROXY"
    '';
  };

  # Generate the proxy-providers section after home.file links the template:
  # one provider entry per file in ~/.config/mihomo/sub-url.d/. The generated
  # file replaces the store symlink with a chmod-600 regular file.
  home.activation.injectSubscriptionUrl = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${pkgs.python3}/bin/python3 - "$HOME/.config/mihomo" "$HOME/.config/mihomo/config.yaml" <<'PY'
    import os, re, sys

    conf_dir, path = sys.argv[1], sys.argv[2]
    if not os.path.exists(path):
        sys.exit(0)

    urls = {}
    d = os.path.join(conf_dir, "sub-url.d")
    if os.path.isdir(d):
        for fn in sorted(os.listdir(d)):
            fp = os.path.join(d, fn)
            if not os.path.isfile(fp):
                continue
            url = open(fp).read().strip()
            if url:
                urls[re.sub(r"[^a-zA-Z0-9_-]", "_", fn)] = url

    data = open(path).read()
    if urls:
        lines = ["proxy-providers:"]
        for name, url in urls.items():
            lines.append(f"  {name}:")
            lines.append("    type: http")
            lines.append(f'    url: "{url}"')
            lines.append("    interval: 86400")
            lines.append(f"    path: ./providers/{name}.yaml")
            lines.append("    health-check:")
            lines.append("      enable: true")
            lines.append('      url: "https://www.gstatic.com/generate_204"')
            lines.append("      interval: 300")
        block = "\n".join(lines)
        out = []
        for line in data.split("\n"):
            if line.strip() == "__PROXY_PROVIDERS__":
                indent = line[: len(line) - len(line.lstrip())]
                out.append("\n".join(indent + l for l in block.split("\n")))
            else:
                out.append(line)
        data = "\n".join(out)
        data = data.replace("__SUBSCRIPTION_NAMES__", ", ".join(urls.keys()))

    if data != open(path).read():
        tmp = path + ".tmp"
        with open(tmp, "w") as f:
            f.write(data)
        os.replace(tmp, path)
        os.chmod(path, 0o600)
    PY
  '';
}
