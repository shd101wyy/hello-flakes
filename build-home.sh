#!/bin/sh
# set -xeu
set -eu

# Check /etc/nix/nix.conf configuration
echo "=========================================="
echo "REMINDER: Please ensure /etc/nix/nix.conf contains:"
echo ""
echo "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/"
echo "experimental-features = nix-command flakes"
echo "trusted-users = your-user-name"
echo ""
echo "=========================================="
echo ""

# Options
# --flake yiyiwang-thinkpad-home
# --flake yiyiwang-steamdeck-home
HOME_CONFIG=""

print_help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --flake <home-config>  Home configuration to use"
  echo "                         --flake yiyiwang-thinkpad-home"
  echo "                         --flake yiyiwang-steamdeck-home"
  echo "                         --flake yiyiwang-wsl-home"
  echo "                         --flake yiyiwang-mac-home"
  echo "  --help, -h             Show this help"
}

# Parse options
while [ $# -gt 0 ]; do
  case "$1" in
  --flake)
    HOME_CONFIG="$2"
    shift 2
    ;;
  --help | -h)
    print_help
    ;;
  *)
    echo "Unknown option: $1" >&2
    exit 1
    ;;
  esac
done

# Check if the HOME_CONFIG is either yiyiwang-thinkpad-home or yiyiwang-steamdeck-home or yiyiwang-wsl-home
if [ "$HOME_CONFIG" != "yiyiwang-thinkpad-home" ] && 
   [ "$HOME_CONFIG" != "yiyiwang-steamdeck-home" ] && 
   [ "$HOME_CONFIG" != "yiyiwang-wsl-home" ] &&
   [ "$HOME_CONFIG" != "yiyiwang-mac-home" ]; then
  echo "Unknown home config: $HOME_CONFIG" >&2
  print_help
  exit 1
fi

# All my machines are running proxy at port 8889
export HTTP_PROXY=http://127.0.0.1:8889
export HTTPS_PROXY=http://127.0.0.1:8889
export http_proxy=http://127.0.0.1:8889
export https_proxy=http://127.0.0.1:8889
export NIX_CURL_FLAGS="-x $http_proxy -x $https_proxy"

export NIXPKGS_ALLOW_UNFREE=1
# export NIXPKGS_ALLOW_INSECURE=1
nix build --impure .\#homeConfigurations.$HOME_CONFIG.activationPackage \
  --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org" #  https://aseipp-nix-cache.global.ssl.fastly.net
"$(nix path-info --impure .\#homeConfigurations.$HOME_CONFIG.activationPackage)"/activate
