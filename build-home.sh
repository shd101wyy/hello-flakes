#!/bin/sh
set -xeu


export HTTP_PROXY=http://127.0.0.1:8889
export HTTPS_PROXY=http://127.0.0.1:8889
export http_proxy=http://127.0.0.1:8889
export https_proxy=http://127.0.0.1:8889

export NIXPKGS_ALLOW_UNFREE=1
nix build  --impure .\#homeConfigurations.yiyiwang-home.activationPackage \
  --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" \
  --option substituters "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
"$(nix path-info --impure .\#homeConfigurations.yiyiwang-home.activationPackage)"/activate

