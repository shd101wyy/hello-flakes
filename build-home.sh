#!/bin/sh
# set -xeu
set -eu

# Check /etc/nix/nix.conf configuration
echo "=========================================="
echo "REMINDER: Please ensure /etc/nix/nix.conf contains:"
echo ""
echo "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/ https://nix-community.cachix.org"
echo "trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
echo "experimental-features = nix-command flakes"
echo "trusted-users = your-user-name @wheel"
echo ""
echo "=========================================="
echo ""

# Options
# --flake yiyiwang-thinkpad-home
# --flake yiyiwang-steamdeck-home
# --proxy-port 8889 (optional; route downloads through a local HTTP proxy;
#                    falls back to the PROXY_PORT env var)
HOME_CONFIG=""
# Proxy port comes from --proxy-port, falling back to PROXY_PORT env var
PROXY_PORT="${PROXY_PORT:-}"

print_help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --flake <home-config>  Home configuration to use"
  echo "                         --flake yiyiwang-thinkpad-home"
  echo "                         --flake yiyiwang-steamdeck-home"
  echo "                         --flake yiyiwang-wsl-home"
  echo "                         --flake yiyiwang-mac-home"
  echo "                         --flake yiyiwang-noproxy-home"
  echo "  --proxy-port <port>    Optional; route downloads through a local"
  echo "                         HTTP proxy at 127.0.0.1:<port> (e.g. 8889)."
  echo "                         Falls back to the PROXY_PORT env var"
  echo "  --help, -h             Show this help"
}

# Parse options
while [ $# -gt 0 ]; do
  case "$1" in
  --flake)
    HOME_CONFIG="$2"
    shift 2
    ;;
  --proxy-port)
    PROXY_PORT="$2"
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
   [ "$HOME_CONFIG" != "yiyiwang-mac-home" ] &&
   [ "$HOME_CONFIG" != "yiyiwang-noproxy-home" ]; then
  echo "Unknown home config: $HOME_CONFIG" >&2
  print_help
  exit 1
fi

# Route downloads through a local HTTP proxy only when --proxy-port (or the
# PROXY_PORT env var) is given
if [ -n "$PROXY_PORT" ]; then
  export HTTP_PROXY=http://127.0.0.1:$PROXY_PORT
  export HTTPS_PROXY=http://127.0.0.1:$PROXY_PORT
  export http_proxy=http://127.0.0.1:$PROXY_PORT
  export https_proxy=http://127.0.0.1:$PROXY_PORT
  export NIX_CURL_FLAGS="-x $http_proxy -x $https_proxy"
fi

export NIXPKGS_ALLOW_UNFREE=1
# export NIXPKGS_ALLOW_INSECURE=1

# Substituters:
#  - USTC/TUNA mirrors + cache.nixos.org cover most packages (fast in China)
#  - nix-community.cachix.org carries packages that Hydra never builds,
#    e.g. terraform (BUSL-1.1 license -> not in the official binary cache).
#    Without it terraform gets built from source, and its go-modules download
#    from proxy.golang.org times out.
nix build --impure .\#homeConfigurations.$HOME_CONFIG.activationPackage \
  --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org https://nix-community.cachix.org" \
  --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
"$(nix path-info --impure .\#homeConfigurations.$HOME_CONFIG.activationPackage)"/activate
