#!/usr/bin/env bash

is_flatpak_app_installed() {
    flatpak list | grep -q "$1"
}

# Check if com.google.Chrome is installed
if is_flatpak_app_installed com.google.Chrome; then
    echo "* Configuring com.google.Chrome"
    # Grant google chrome access to the following folders to install or uninstall PWAs:
    # ~/.local/share/applications
    # ~/.local/share/icons
    flatpak override --reset --user com.google.Chrome
    flatpak override --user --filesystem=~/.local/share/applications com.google.Chrome
    flatpak override --user --filesystem=~/.local/share/icons com.google.Chrome
    flatpak override --user --filesystem=host
fi

# Check if com.visualstudio.code is installed
if is_flatpak_app_installed com.visualstudio.code; then
    echo "* Configuring com.visualstudio.code"
    # Grant vscode access to the following folders
    flatpak override --reset --user com.visualstudio.code
    flatpak override --user --filesystem=host com.visualstudio.code
    flatpak override --user --filesystem=host-os com.visualstudio.code
    flatpak override --user --filesystem=host-etc com.visualstudio.code
    flatpak override --user --filesystem=home com.visualstudio.code
fi