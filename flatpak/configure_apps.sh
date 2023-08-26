#!/usr/bin/env bash
# Run "flatpak run --command=bash com.visualstudio.code" to check the running environments.
# Run "flatpak enter com.visualstudio.code bash" to enter the sandbox environment.

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
    # Set environment variables
    flatpak override --user --env=PATH="/app/bin:/usr/bin:$PATH" com.visualstudio.code
fi

# Check if com.slack.Slack is installed
if is_flatpak_app_installed com.slack.Slack; then
    echo "* Configuring com.slack.Slack"
    flatpak override --reset --user com.slack.Slack
    # Disable the socket=wayland
    flatpak override --user --nosocket=wayland com.slack.Slack
fi

# Check if com.raggesilver.BlackBox is installed
if is_flatpak_app_installed com.raggesilver.BlackBox; then
    echo "* Configuring com.raggesilver.BlackBox"
    flatpak override --reset --user com.raggesilver.BlackBox

    # Grant access to the following folders
    flatpak override --user --filesystem=host com.raggesilver.BlackBox
    flatpak override --user --filesystem=host-os com.visualstudio.code
    flatpak override --user --filesystem=host-etc com.visualstudio.code
    flatpak override --user --filesystem=home com.visualstudio.code

    # Not working below:
    # Set environment variables
    ## Curl reads and understands the following environment variables:
    # PROXY=http://127.0.0.1:8889
    # flatpak override --user --env=HTTP_PROXY="$PROXY" com.raggesilver.BlackBox
    # flatpak override --user --env=HTTPS_PROXY="$PROXY" com.raggesilver.BlackBox
    # flatpak override --user --env=http_proxy="$PROXY" com.raggesilver.BlackBox
    # flatpak override --user --env=https_proxy="$PROXY" com.raggesilver.BlackBox

    ## They should be set for protocol-specific proxies. General proxy should be set with
    # ALL_PROXY=socks://127.0.0.1:8889
    # flatpak override --user --env=ALL_PROXY="$ALL_PROXY" com.raggesilver.BlackBox
    # flatpak override --user --env=all_proxy="$ALL_PROXY" com.raggesilver.BlackBox

    ## A comma-separated list of host names that shouldn't go through any proxy is set in (only an asterisk, '*' matches all hosts)
    # NO_PROXY=localhost,127.0.0.1,::1
    # flatpak override --user --env=NO_PROXY="$NO_PROXY" com.raggesilver.BlackBox
    # flatpak override --user --env=no_proxy="$NO_PROXY" com.raggesilver.BlackBox
fi
