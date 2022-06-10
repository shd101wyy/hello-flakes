{
  description = "A very basic flake";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-22.05"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        packages = {
          hello = pkgs.stdenv.mkDerivation {
            name = "hello";
            src = self;
            buildPhase = "gcc -o hello ./hello.c";
            installPhase = "mkdir -p $out/bin; install -t $out/bin hello";
          };
          test = pkgs.stdenv.mkDerivation {
            name = "test";
            src = self;
            buildPhase = "gcc -o test ./test.c";
            installPhase = "mkdir -p $out/bin; install -t $out/bin test";
          };
        };
        defaultPackage = packages.hello;
        devShell = import ./shell.nix { inherit pkgs; };
      });

}
