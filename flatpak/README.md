# Flatpak

## Installation

Under `configuration.nix`:

```
services.flatpak.enable = true;
```

Then rebuild, and add the Flathub repository:

```bash
$ flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

## Install apps

Check the [Flathub website](https://flathub.org/home) for available apps.

Check the [install_apps.sh](./install_apps.sh) script for some examples.
