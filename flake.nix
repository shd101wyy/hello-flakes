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
      # * It causes grub bug, so I have to roll back to nixos-23.05
      # url = "github:NixOS/nixpkgs?rev=42c25608aa2ad4e5d3716d8d63c606063513ba33";
      #
      # Below is the nixos-22.11
      # url = "github:NixOS/nixpkgs?rev=60c0f762658916a4a5b5a36b3e06486f8301daf4";
      #
      # Below is the nixos-23.05
      # url = "github:NixOS/nixpkgs?rev=da4024d0ead5d7820f6bd15147d3fe2a0c0cec73";
      # Below is the nixos-23.11
      # url = "github:NixOS/nixpkgs?rev=12430e43bd9b81a6b4e79e64f87c624ade701eaf";
      # Below is the nixos-24.05
      url = "github:NixOS/nixpkgs?rev=805a384895c696f802a9bf5bf4720f37385df547";
    };
    nixpkgs-unstable = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    flake-utils = { url = "github:numtide/flake-utils"; };
    nur = { url = "github:nix-community/NUR/master"; };
    home-manager = {
      url = "github:nix-community/home-manager?ref=release-24.05"; # The version here should match `nixpkgs`
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-doom-emacs = {
      url = "github:nix-community/nix-doom-emacs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, flake-utils, nur, home-manager, nix-doom-emacs }@attrs:
    flake-utils.lib.eachDefaultSystem
      (system:
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
        })) // (
      let
        system = "x86_64-linux";
        pkgs = nixpkgs.legacyPackages.${system};
        pkgsUnstable = nixpkgs-unstable.legacyPackages.${system};
      in
      {

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
              nix-doom-emacs.hmModule
              ./home/yiyiwang-thinkpad-home.nix
              ./home/common.nix 
            ];

            # Optionally use extraSpecialArgs
            # to pass through arguments to home.nix
            extraSpecialArgs = { inherit pkgsUnstable; };
          };

        homeConfigurations.yiyiwang-steamdeck-home =
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [ 
              nix-doom-emacs.hmModule
              ./home/yiyiwang-steamdeck-home.nix 
              ./home/common.nix 
            ];

            # Optionally use extraSpecialArgs
            # to pass through arguments to home.nix
            extraSpecialArgs = { inherit pkgsUnstable; };
          };
      }
    );
}
