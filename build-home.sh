#!/bin/sh
set -xeu

export NIXPKGS_ALLOW_UNFREE=1
nix build  --impure .\#homeConfigurations.yiyiwang-home.activationPackage
"$(nix path-info --impure .\#homeConfigurations.yiyiwang-home.activationPackage)"/activate

