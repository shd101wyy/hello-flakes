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
