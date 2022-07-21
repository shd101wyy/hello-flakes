{
  description = "A very basic flake";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/nixos-unstable"; };
    flake-utils = { url = "github:numtide/flake-utils"; };
    nur = { url = "github:nix-community/NUR/master"; };
    home-manager = { url = "github:nix-community/home-manager"; };
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, nur, home-manager }@attrs:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in (rec {
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
      })) // (let
        system = "x86_64-linux";
        pkgs = nixpkgs.legacyPackages.${system};
      in {

        # NixOS configurations
        # Run the following command to build the NixOS configuration
        # $ sudo nixos-rebuild switch --flake .#yiyiwang-thinkpad
        # Read the `configuration.nix` for more comments
        nixosConfigurations.yiyiwang-thinkpad = nixpkgs.lib.nixosSystem (rec {
          inherit system;
          specialArgs = { inherit nur; };
          modules = [ ./nixos/yiyiwang-thinkpad/configuration.nix ];
        });

        # Home configurations
        # Run the following command to build the home-manager configuration
        # $ nix build .\#homeConfigurations.yiyiwang-home.activationPackage
        homeConfigurations.yiyiwang-home = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
        };
      });
}
