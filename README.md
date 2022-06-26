# Nix Flakes study

https://nixos.wiki/wiki/Flakes

## Build

```bash
# Build all
nix build .

# Build specific attribute
nix build .#hello
nix build .#test
```

## Update

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