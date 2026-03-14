{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell {
  buildInputs = [ 
    bash
  ];
  shellHook = ''
    # ...
  '';
}
