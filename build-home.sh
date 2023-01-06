#!/bin/sh
set -xeu

# Options
# --home yiyiwang-thinkpad-home
# --home yiyiwang-steamdeck-home
HOME_CONFIG=""

# Parse options
while [ $# -gt 0 ]; do
  case "$1" in
  --home)
    HOME_CONFIG="$2"
    shift 2
    ;;
  --help|-h)
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --home <home-config>  Home configuration to use"
    echo "                        --home yiyiwang-thinkpad-home"
    echo "                        --home yiyiwang-steamdeck-home"
    echo "  --help, -h            Show this help"
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    exit 1
    ;;
  esac
done

# Check if the HOME_CONFIG is either yiyiwang-thinkpad-home or yiyiwang-steamdeck-home
if [ "$HOME_CONFIG" != "yiyiwang-thinkpad-home" ] && [ "$HOME_CONFIG" != "yiyiwang-steamdeck-home" ]; then
  echo "Unknown home config: $HOME_CONFIG" >&2
  echo "Please use --home yiyiwang-thinkpad-home or --home yiyiwang-steamdeck-home" >&2
  exit 1
fi

# export HTTP_PROXY=http://127.0.0.1:8889
# export HTTPS_PROXY=http://127.0.0.1:8889
# export http_proxy=http://127.0.0.1:8889
# export https_proxy=http://127.0.0.1:8889

export NIXPKGS_ALLOW_UNFREE=1
nix build --impure .\#homeConfigurations.$HOME_CONFIG.activationPackage \
  --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org"
"$(nix path-info --impure .\#homeConfigurations.$HOME_CONFIG.activationPackage)"/activate
