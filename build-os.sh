#!/bin/sh

ID=`id -u`
if [ $ID -ne 0 ]; then
  echo "This command must be run as root."
  exit 1
fi

export HTTP_PROXY=http://127.0.0.1:8889
export HTTPS_PROXY=http://127.0.0.1:8889
export http_proxy=http://127.0.0.1:8889
export https_proxy=http://127.0.0.1:8889

# Hack for neo4j
rm -rf /home/yiyiwang/.local/neo4j/logs/debug.log

nixos-rebuild switch --flake .#yiyiwang-thinkpad -v
