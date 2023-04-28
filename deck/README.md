# Steam Deck Configuration

## 添加国内 Flatpak 镜像

```bash
$ sudo flatpak remote-modify flathub --url=https://mirror.sjtu.edu.cn/flathub
$ flatpak remotes --show-details
```

如果 `flatpak` 中不存在 `flathub` 源的话，则添加：

```bash
flatpak remote-add --if-not-exists flathub https://mirror.sjtu.edu.cn/flathub
```

## Upgrade Nix on Steam Deck

```bash
$ curl -L https://nixos.org/nix/install | sh -s -- --daemon
```

## Enable `nix` experimental features

Edit either `~/.config/nix/nix.conf` or `/etc/nix/nix.conf` and add:

```text
experimental-features = nix-command flakes
```