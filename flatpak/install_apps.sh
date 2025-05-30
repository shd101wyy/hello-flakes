#!/usr/bin/env bash

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
# For China
# sudo flatpak remote-modify flathub --url=https://mirror.sjtu.edu.cn/flathub

flatpak update -y
# If this command failed or gives a bunch of warnings, try to run:
# $ flatpak repair 
# Actually this^ doesn't help. But the ones below work:
# $flatpak remote-delete --force flathub
# $flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# An array of apps to install
apps=(
    com.calibre_ebook.calibre
    com.discordapp.Discord
    com.github.johnfactotum.Foliate
    com.github.marhkb.Pods
    com.github.tchx84.Flatseal
    com.github.xournalpp.xournalpp
    com.orama_interactive.Pixelorama
    com.qq.QQ
    com.qq.QQmusic
    com.raggesilver.BlackBox
    com.skype.Client
    com.slack.Slack
    com.uploadedlobster.peek
    com.wps.Office
    io.dbeaver.DBeaverCommunity
    
    # NOTE: This is actually worse than clash_verge
    # io.github.Fndroid.clash_for_windows
    
    io.github.giantpinkrobots.flatsweep
    io.podman_desktop.PodmanDesktop
    # net.codeindustry.MasterPDFEditor
    org.filezillaproject.Filezilla
    org.gimp.GIMP
    org.gnome.FontManager
    org.gnome.seahorse.Application
    org.kde.kwalletmanager5
    org.mozilla.firefox
    org.sqlitebrowser.sqlitebrowser
    org.videolan.VLC
    rest.insomnia.Insomnia
)

# Check if the OS is NixOS. If not, then install some extra apps
is_nixos=$(test -f /etc/NIXOS && echo 0 || echo 1)
echo "* Is NixOS: $(test -f /etc/NIXOS && echo True || echo False)"
if [[ $is_nixos -eq 1 ]]; then
    apps+=(
        com.google.Chrome
        com.visualstudio.code # Have xdg-open problem

        # Input
        org.fcitx.Fcitx5
        org.gnome.font-viewer

        com.tencent.WeChat
    )
fi

# Check if the OS is SteamOS. If yes then install some extra apps
if [ -f /etc/os-release ] && grep -q 'NAME="SteamOS"' /etc/os-release; then
    echo "* Detected SteamOS"
    apps+=(
        # Game emulator
        app.xemu.xemu
        io.github.shiiion.primehack
        io.mgba.mGBA
        net.davidotek.pupgui2
        net.kuribo64.melonDS
        net.rpcs3.RPCS3
        org.citra_emu.citra
        org.DolphinEmu.dolphin-emu
        org.duckstation.DuckStation
        org.libretro.RetroArch
        org.ppsspp.PPSSPP
        org.scummvm.ScummVM
    )
fi

# Install apps
echo "* Installing apps..."
for app in "${apps[@]}"; do
    echo "= Installing $app"
    flatpak install -y --or-update flathub "$app"
done

# NOTE: Let's not uninstall apps that are not in the list for now
# Delete app not in the list
## echo "* Uninstalling apps..."
## installed_apps=$(flatpak list --app --columns=application)
## for app in $installed_apps; do
##     if [[ ! " ${apps[@]} " =~ " ${app} " ]]; then
##         echo "= Uninstalling $app"
##         flatpak uninstall -y "$app"
##     fi
## done

# Run configure_apps.sh
echo "* Configuring apps..."
$(dirname "$0")/configure_apps.sh

echo "*You may need to log out then log in again to make app installed by flatpak work."
