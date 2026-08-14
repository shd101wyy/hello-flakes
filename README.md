# Nix Flakes study

https://nixos.wiki/wiki/Flakes

## Build package

```bash
# Build all
nix build .

# Build specific attribute
nix build .#hello
nix build .#test
```

# Build NixOS Configuration

```bash
sudo nixos-rebuild switch --flake .#yiyiwang-thinkpad -v
```

## Update dependencies

```bash
# Update all
nix flake update

# Update specific package
nix flake lock --update-input $PKG1 --update-input $PKG2
```

## Shell

```bash
# Enter the environment defined by `shell.nix`
nix develop
```

## Repl

```bash
# Evaluate `repl.nix` and enter repl. `flake` variable will be available
nix repl repl.nix
```

To use `pkgs` from `nixpkgs` imported in `flake.nix`:

```
Welcome to Nix 2.8.0. Type :? for help.

Loading 'repl.nix'...
Added 1 variables.

nix-repl> pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux
```

## Set Proxy for Nix on macOS

If you need a proxy (e.g., Clash) to speed up Nix downloads, run:

```bash
sudo python3 set_macos_nix_proxy_with_sudo.py
```

This sets `http_proxy` and `https_proxy` in the nix-daemon LaunchDaemon plist and reloads the service. Edit `HTTP_PROXY` in the script to match your proxy address (default: `http://127.0.0.1:8889`).

To remove the proxy, uncomment the "remove http proxy" lines in the script and comment out the "set" lines, then run it again.

## Install Nix on Steam Deck

Follow https://determinate.systems/posts/nix-on-the-steam-deck

After installing applications, the application might not show in the menu.  
We will need to open `Menu Editor` then add the executable paths of the applications manually.

## Install Tailscale on Steam Deck

> https://github.com/tailscale-dev/deck-tailscale

```bash
# 1. Clone and install (installs binaries to /opt/tailscale, enables systemd service)
git clone https://github.com/tailscale-dev/deck-tailscale.git ~/deck-tailscale
sudo -i
cd ~deck/deck-tailscale
bash tailscale.sh

# 2. Put binaries in PATH (this repo's home config already adds /opt/tailscale
#    to PATH via home/common.nix, so this is only needed in fresh shells)
source /etc/profile.d/tailscale.sh

# 3. Authenticate (scan the QR code with your phone)
tailscale up --qr --operator=deck --ssh
```

Notes:

- The service starts automatically on boot.
- Update with `sudo tailscale update`; enable auto-updates with `sudo tailscale set --auto-update`.
- To update the install script itself, `git pull` in `~/deck-tailscale` and re-run `sudo bash tailscale.sh`. The config at `/etc/default/tailscaled` is kept; `override.conf` is reset (old one saved as `override.conf.bak`).
- If you see `invalid value "" for flag -port: can't be the empty string`, delete `/etc/default/tailscaled` and re-run the installer.

## Mihomo (Clash Meta) on Steam Deck

Headless proxy service replacing Clash Verge (which only ran in desktop mode).
It serves a mixed HTTP/SOCKS proxy on `127.0.0.1:8889` (matching `proxyPort`
in `flake.nix`) and exposes the Clash API on `127.0.0.1:9090`. The service is
declared in `home/yiyiwang-steamdeck-home.nix`
(`systemd.user.services.mihomo`) and starts at boot even in game mode once
linger is enabled:

```bash
sudo loginctl enable-linger deck
```

### Set the subscription URL (private)

Subscription URLs are never committed to this repo. Each one lives in its own
file under `~/.config/mihomo/sub-url.d/` (chmod 600); the file name becomes
the mihomo provider name. A home-manager activation hook generates the
`proxy-providers` section of `config.yaml` from these files:

```bash
mkdir -p ~/.config/mihomo/sub-url.d
printf '%s\n' 'https://your-provider/sub?token=...&format=clash' > ~/.config/mihomo/sub-url.d/jms
printf '%s\n' 'https://another-provider/sub?token=...&format=clash' > ~/.config/mihomo/sub-url.d/airport2
chmod 600 ~/.config/mihomo/sub-url.d/*
./build-home.sh --flake yiyiwang-steamdeck-home   # re-activate to re-generate
systemctl --user restart mihomo
```

- **Multiple subscriptions**: just add more files — all providers are merged
  into the `PROXY`/`AUTO` groups automatically.
- **Add/remove/rename** a subscription: edit the files, re-activate, restart.
  (Old provider caches live in `~/.config/mihomo/providers/`.)
- If the URL changes, update the file and re-activate as above. The generated
  `~/.config/mihomo/config.yaml` is also chmod 600.

### Subscription refresh

- **Automatic every 24h** — `interval: 86400` on the `jms` provider in the
  config template. mihomo re-fetches the subscription in the background.
- **Health checks every 5min** — `interval: 300`; the `AUTO` group always uses
  the fastest alive node, so dead nodes are skipped automatically.
- **On all-nodes-failure** — the `mihomo-refresh.timer` (every 15min) runs
  `mihomo-ctl refresh-if-dead`, which force-refreshes the subscription only when
  every node is dead AND the last refresh is older than 1h.
- **Manual** — `mihomo-ctl refresh`, or:
  `curl -X PUT http://127.0.0.1:9090/providers/proxies/jms`

### Pick a node manually

```bash
mihomo-ctl current                        # which node is selected right now
mihomo-ctl status                         # provider summary + UP/DOWN + last delay
mihomo-ctl test                           # live latency of every node
mihomo-ctl set-node "YOUR-NODE-NAME"      # pick a node (use a name from `mihomo-ctl test`)
mihomo-ctl set-node "AUTO"                # back to auto-selecting the fastest alive node
```

or via the API:

```bash
curl -X PUT http://127.0.0.1:9090/proxies/PROXY \
  -H 'Content-Type: application/json' \
  -d '{"name":"YOUR-NODE-NAME"}'
```

The choice persists in `~/.config/mihomo/cache.db` across restarts; the `AUTO`
group reselects on health changes. For a GUI, point a Clash dashboard (e.g.
metacubexd) at `http://127.0.0.1:9090`.

### Troubleshooting

```bash
systemctl --user status mihomo
journalctl --user -u mihomo -f
```

## dsh-ctl (DeepSeek Harness Web UI)

[dsh](https://www.deepseek.com/harness/) is DeepSeek's agent harness. On Nix
machines the npm global prefix is a read-only Nix store and Node refuses
`--expose-internals` inside `NODE_OPTIONS`, so `npm i -g` and plain `npx`
don't work. `dsh-ctl` (installed to `~/.local/bin` by `home/common.nix`)
works around both: it installs the package into the user-writable
`~/.local/share/dsh` and launches it directly with `node --expose-internals`.

```bash
dsh-ctl install                     # install (or update to) the latest @deepseek-ai/dsh
dsh-ctl start [--profile NAME] [--port PORT]   # start in the background
dsh-ctl status                      # running? (pid + every URL that actually answers)
dsh-ctl stop                        # stop it
dsh-ctl exec --help                 # pass args through to the dsh CLI itself
```

The Web UI listens on `http://127.0.0.1:3080` by default; `status`/`start` also
show any LAN URL (e.g. `http://192.168.3.238:3080`) that actually answers.
Override the install dir with `DSH_ROOT`, the bind host with `DSH_HOST`, the
default port with `DSH_PORT`, and the node/npm binaries with `DSH_NODE` /
`DSH_NPM`.

Note: dsh refuses `--host 0.0.0.0` for safety (it would expose the agent's
remote code execution to the network), so `DSH_HOST=0.0.0.0` is rejected by
both dsh and dsh-ctl.

## Install wechat

> https://github.com/NixOS/nixpkgs/issues/349245

Download `license.tar.gz` from https://aur.archlinux.org/packages/wechat-uos, then run the following command before installing wechat:

```bash
$ nix-store --add-fixed sha256 license.tar.gz
```

## WSL NixOS

Check https://github.com/nix-community/NixOS-WSL

If you are using clash, then make sure you turn off the `Tun` mode and enable the `System Proxy`.  

Also, enable the WSL `mirrored` network mode. 

`sudo nix-channel --update` might only work for `root` user in the beginning under the proxy mode. You need to use `sudo -E` to pass the environment variables to the `nix-channel` command. So it's `sudo -E nix-channel --update`.
