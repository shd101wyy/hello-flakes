#!/bin/sh

ID=`id -u`
if [ $ID -ne 0 ]; then
  echo "This command must be run as root."
  exit 1
fi

export HTTP_PROXY=http://127.0.0.1:8889
export HTTPS_PROXY=http://127.0.0.1:8889
nixos-rebuild switch --flake .#yiyiwang-thinkpad
