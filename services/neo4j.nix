{ pkgs, ... }:

{
  # https://nixos.wiki/wiki/Neo4j
  services.neo4j.enable = true;
  services.neo4j.package = pkgs.neo4j;
}
