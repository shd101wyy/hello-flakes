#!/usr/bin/env bash

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
# For China
# sudo flatpak remote-modify flathub --url=https://mirror.sjtu.edu.cn/flathub

flatpak update -y

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
    com.skype.Client
    com.uploadedlobster.peek
    com.wps.Office
    io.dbeaver.DBeaverCommunity
    io.github.giantpinkrobots.flatsweep
    io.podman_desktop.PodmanDesktop
    net.codeindustry.MasterPDFEditor
    org.filezillaproject.Filezilla
    org.gimp.GIMP
    org.mozilla.firefox
    org.videolan.VLC
    rest.insomnia.Insomnia
)

# Check if the OS is NixOS. If not, then install some extra apps
is_nixos=$(test -f /etc/NIXOS && echo 0 || echo 1)
echo "* Is NixOS: $(test -f /etc/NIXOS && echo True || echo False)"
if [[ $is_nixos -eq 1 ]]; then
    apps+=(
        com.google.Chrome
        com.slack.Slack
        com.visualstudio.code
    )
fi

# Install apps
echo "* Installing apps..."
for app in "${apps[@]}"; do
    echo "= Installing $app"
    flatpak install -y --or-update flathub "$app"
done

# Delete app not in the list
echo "* Uninstalling apps..."
installed_apps=$(flatpak list --app --columns=application)
for app in $installed_apps; do
    if [[ ! " ${apps[@]} " =~ " ${app} " ]]; then
        echo "= Uninstalling $app"
        flatpak uninstall -y "$app"
    fi
done

if [[ $is_nixos -eq 1 ]]; then
    # Grant google chrome access to the following folders to install or uninstall PWAs:
    # ~/.local/share/applications
    # ~/.local/share/icons
    flatpak override --reset --user com.google.Chrome
    flatpak override --user --filesystem=~/.local/share/applications com.google.Chrome
    flatpak override --user --filesystem=~/.local/share/icons com.google.Chrome
    flatpak override --user --filesystem=host

    # Grant vscode access to the following folders
    flatpak override --reset --user com.visualstudio.code
    flatpak override --user --filesystem=host-etc com.visualstudio.code
fi

echo "*You may need to log out then log in again to make app installed by flatpak work."
