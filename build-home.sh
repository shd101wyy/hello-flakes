#!/bin/sh
nix build .\#homeConfigurations.yiyiwang-home.activationPackage
"$(nix path-info .\#homeConfigurations.yiyiwang-home.activationPackage)"/activate 

