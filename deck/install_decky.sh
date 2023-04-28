#!/usr/bin/env sh
# The project is at https://github.com/SteamDeckHomebrew/decky-loader

export HTTP_PROXY=http://127.0.0.1:8889
export HTTPS_PROXY=http://127.0.0.1:8889
export http_proxy=http://127.0.0.1:8889
export https_proxy=http://127.0.0.1:8889

curl -L http://dl.ohmydeck.net | sh # 国内源
# curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh
