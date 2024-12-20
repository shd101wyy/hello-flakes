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