{
  description = "A very basic flake";

  inputs = {
    nixpkgs = {
      # https://status.nixos.org/ Use this website to check the binary cache status,
      # sometimes the latest commit of the nixos-unstable channel is not cached yet.
      #
      # Sometimes a package might take very long time to build, that is because it is not cached yet.
      # So we might want to roll back to some previous commit.
      #
      # Below is the unixos-unstable
      # url = "github:NixOS/nixpkgs?rev=61a8a98e6d557e6dd7ed0cdb54c3a3e3bbc5e25c";
      #
      # Below is the nixos-22.11
      url = "github:NixOS/nixpkgs?rev=e6d5772f3515b8518d50122471381feae7cbae36";
    };
    flake-utils = { url = "github:numtide/flake-utils"; };
    nur = { url = "github:nix-community/NUR/master"; };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

        # If you want to enable the dev shell, you need to add the following line: 
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
        # $ nix build .\#homeConfigurations.yiyiwang-thinkpad-home.activationPackage
        # $ "$(nix path-info .\#homeConfigurations.yiyiwang-thinkpad-home.activationPackage)"/activate 
        homeConfigurations.yiyiwang-thinkpad-home =
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [ 
              ./home/yiyiwang-thinkpad-home.nix
              ./home/common.nix
            ];

            # Optionally use extraSpecialArgs
            # to pass through arguments to home.nix
          };
        
        homeConfigurations.yiyiwang-steamdeck-home =
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [ 
              ./home/yiyiwang-steamdeck-home.nix
              ./home/common.nix
            ];

            # Optionally use extraSpecialArgs
            # to pass through arguments to home.nix
          };
      });
}
