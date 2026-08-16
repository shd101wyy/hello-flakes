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

`dsh-ctl install` resolves the registry's `latest` version with `npm view`
and installs it with **pnpm** when available. pnpm is required on machines
where npm's resolver spins forever on the dsh peer-dependency graph (npm 11
hangs at 100% CPU building the ideal tree for it, e.g. on Steam Deck).

```bash
dsh-ctl install                     # install (or update to) the latest @deepseek-ai/dsh
dsh-ctl patch                       # re-apply the LAN patch (allows --host 0.0.0.0)
dsh-ctl start [dsh web flags...]    # start in the background
dsh-ctl status                      # every running instance (pid + URLs)
dsh-ctl stop                        # stop every instance
dsh-ctl stop --port PORT            # stop just the instance on PORT
dsh-ctl restart                     # restart every instance
dsh-ctl restart --port PORT         # restart just the instance on PORT
dsh-ctl exec --help                 # pass args through to the dsh CLI itself
dsh-tui --help                      # same as: dsh-ctl exec --profile cc-tui --help
dsh-tui update                      # update the dsh-cc-tui plugin to its latest version
```

The Web UI listens on `http://127.0.0.1:3080` by default; `status`/`start` also
show any LAN URL (e.g. `http://192.168.3.243:3080`) that actually answers.
Override the install dir with `DSH_ROOT`, the bind host with `DSH_HOST`, the
default port with `DSH_PORT`, and the node/npm/pnpm binaries with `DSH_NODE` /
`DSH_NPM` / `DSH_PNPM`.

`dsh-ctl start` is a thin supervisor over `dsh web`: every flag after the
dsh-ctl ones is forwarded verbatim, so `dsh-ctl start ARGS...` behaves exactly
like `dsh web ARGS...` while still running in the background and tracked by
`status`/`stop`. `dsh-ctl start --help` prints `dsh web`'s usage and exits
without starting anything. The current flags are `--host`, `--port`, and the
repeatable `--trusted-host`; `--host`/`--port` are also used by dsh-ctl for
its health checks and status output (e.g. `dsh-ctl start --host 0.0.0.0 --port
5000`). `--profile NAME` stays a dsh-ctl-only flag for non-web profiles.

Each port runs its own independent instance (one instance per port), tracked
in `dsh.pid.<port>` / `dsh.state.<port>` / `dsh.log.<port>` under `DSH_ROOT`.
Start a second one on another port while the first is running; `status` lists
every instance, `stop` stops all of them, and `stop --port 3081` stops just
that one.

`restart` replays each instance's recorded launch (host, port, profile, and
extra web flags are stored in its state file), so `dsh-ctl restart` after a
reboot brings every previously-running instance back up, and
`restart --port 3081` cycles just one. Restarting drops and re-creates each
instance: brief downtime, then the same URLs answer again.

To expose the Web UI to other devices on the LAN, allow all-interfaces binding
first (`dsh-ctl install` applies this patch automatically, `dsh-ctl patch`
re-applies it after the fact):

```bash
dsh-ctl patch                       # one-time (idempotent)
dsh-ctl start --host 0.0.0.0        # serve on every interface
```

Other devices can then open `http://<this machine's LAN IP>:3080`, e.g.
`http://192.168.3.243:3080`; dsh derives the LAN IPs it trusts from the
interfaces itself, and dsh-ctl's `status` prints every URL that actually
answers.

The patch also injects a `crypto.randomUUID` polyfill into the served
`index.html`: dsh's browser half calls `crypto.randomUUID()`, which browsers
only expose in *secure contexts*. `http://127.0.0.1` counts as secure
(loopback), but plain-HTTP LAN origins do not, so without the polyfill the
settings/workspace dialogs crash with `crypto.randomUUID is not a function`
on LAN devices (iPhone Safari/Brave enforce this strictly).

One more dsh gate keeps the *privileged* API methods (`settings.describe` /
`settings.update` / `credentials.*` / `host.pickDirectory` / `host.openPath`
/ `llm.discoverModels`, ...) pinned to loopback even on LAN deployments —
the settings and workspace-directory dialogs then fail with
`transport failure for /api/settings.describe: HTTP 403`. `dsh-ctl patch`
also lifts that: the privileged gate honors the same `trustedHosts` the rest
of `/api` already uses, so those dialogs work from LAN browsers too (an
untrusted `Host` header still gets 403).

> **Security warning:** dsh's Web UI has **no authentication layer** — anyone
> who can reach the port gets full remote code execution through the harness.
> The `/api` trust fence only blocks *other* hostnames (DNS-rebinding), not
> other devices on the LAN. `0.0.0.0` also exposes the UI on every other
> interface (Tailscale, VPNs, ...), so only do this on a trusted network.
> Upstream removes the rejection line only on demand:
> "`dsh web --host 0.0.0.0` is intentionally unsupported until remote access
> has an authentication layer", hence the patch. `dsh-ctl install` re-applies
> it after each update.

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
