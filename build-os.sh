#!/bin/sh

ID=$(id -u)
if [ $ID -ne 0 ]; then
  echo "This command must be run as root."
  exit 1
fi

export HTTP_PROXY=http://127.0.0.1:8889
export HTTPS_PROXY=http://127.0.0.1:8889
export http_proxy=http://127.0.0.1:8889
export https_proxy=http://127.0.0.1:8889
export NIX_CURL_FLAGS="-x $http_proxy -x $https_proxy"

# Hack for neo4j
rm -rf /home/yiyiwang/.local/neo4j/logs/debug.log

nixos-rebuild switch --flake .#yiyiwang-thinkpad -v \
  --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://aseipp-nix-cache.global.ssl.fastly.net https://cache.nixos.org"

# If the substitue doesn't work, add `--option substitute false`
# nixos-rebuild switch --flake .#yiyiwang-thinkpad -v --option substitute false
