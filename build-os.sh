#!/bin/sh

ID=$(id -u)
if [ $ID -ne 0 ]; then
  echo "This command must be run as root."
  echo "sudo -E ./build-os.sh --flake <flake-name>"
  exit 1
fi

# Options
# --flake yiyiwang-thinkpad
# --flake yiyiwang-wsl
FLAKE_CONFIG=""

# Parse options
while [ $# -gt 0 ]; do
  case "$1" in
  --flake)
    FLAKE_CONFIG="$2"
    shift 2
    ;;
  --help | -h)
    echo "Usage: sudo -E $0 [options]"
    echo "Options:"
    echo "  --flake <flake-config>  NixOS configuration to use"
    echo "                          --flake yiyiwang-thinkpad"
    echo "                          --flake yiyiwang-wsl"
    echo "  --help, -h              Show this help"
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    exit 1
    ;;
  esac
done

# Check if the FLAKE_CONFIG is either yiyiwang-thinkpad or yiyiwang-wsl
if [ "$FLAKE_CONFIG" != "yiyiwang-thinkpad" ] && 
   [ "$FLAKE_CONFIG" != "yiyiwang-wsl" ]; then
  echo "Unknown flake config: $FLAKE_CONFIG" >&2
  echo "Please use '--flake yiyiwang-thinkpad' or '--flake yiyiwang-wsl'" >&2
  exit 1
fi

export HTTP_PROXY=http://127.0.0.1:8889
export HTTPS_PROXY=http://127.0.0.1:8889
export http_proxy=http://127.0.0.1:8889
export https_proxy=http://127.0.0.1:8889
export NIX_CURL_FLAGS="-x $http_proxy -x $https_proxy"

# Hack for neo4j
rm -rf /home/yiyiwang/.local/neo4j/logs/debug.log

nixos-rebuild switch --flake .#$FLAKE_CONFIG -v \
  --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://aseipp-nix-cache.global.ssl.fastly.net https://cache.nixos.org" \
  --impure

# If the substitue doesn't work, add `--option substitute false`
# nixos-rebuild switch --flake .#yiyiwang-thinkpad -v --option substitute false
