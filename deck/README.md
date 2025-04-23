# Steam Deck Configuration

## 添加国内 Flatpak 镜像

```bash
$ flatpak remote-modify flathub --url=https://mirror.sjtu.edu.cn/flathub
$ flatpak remotes --show-details
```

如果 `flatpak` 中不存在 `flathub` 源的话，则添加：

```bash
flatpak remote-add --if-not-exists flathub https://mirror.sjtu.edu.cn/flathub
```

## Official Flatpak remote

```bash
$ flatpak remote-modify flathub --url=https://flathub.org/repo/flathub.flatpakrepo
```

## Upgrade Nix on Steam Deck

```bash
$ curl -L https://nixos.org/nix/install | sh -s -- --daemon
```

## Install direnv on Steam Deck

```bash
$ curl -sfL https://direnv.net/install.sh | bash
```

## Enable `nix` experimental features

Edit either `~/.config/nix/nix.conf` or `/etc/nix/nix.conf` and add:

```text
experimental-features = nix-command flakes
```

## Install podman

[Guid](https://www.gamingonlinux.com/2022/09/distrobox-can-open-up-the-steam-deck-to-a-whole-new-world/)
[Guid2](https://engineering.zeroitlab.com/2022/09/20/develop-on-deck/)
[install_podman.sh](./install_podman.sh)

```bash
$ ./install_podman.sh
```

## KWallet

Steam Deck is currently using the KDE5, not 6, so installing the latest KWallet will not work with KDE5.  

Related discussion: https://www.reddit.com/r/kde/comments/1c4hu5y/cannot_run_kwalletmanager_on_my_steam_deck/

Downgrade to KWallet5 manually:

```bash
$ flatpak update --commit=cf3a6420de76bed4ead3d5546bd6a9f402af26941d26bafa5be9de3da42bbb98 org.kde.kwalletmanager5
$ flatpak mask org.kde.kwalletmanager5
```

Once Steam Deck updates to Plasma 6, revert it by:

```bash
$ flatpak mask --remove org.kde.kwalletmanager5
```

