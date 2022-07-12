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