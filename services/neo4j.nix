{ pkgs, ... }:

{
  # https://nixos.wiki/wiki/Neo4j
  services.neo4j.enable = true;
  services.neo4j.package = pkgs.neo4j;
  services.neo4j.bolt.enable = true;
  services.neo4j.bolt.tlsLevel = "DISABLED";
  services.neo4j.https.enable = false;

  # NOTE: Setting this below will cause the service to fail to start
  # services.neo4j.directories.home = "/home/yiyiwang/.local/neo4j";

  # For my case, run the following:
  # NOTE: Probably don't need to export NEO4j_CONF
  # $ export NEO4J_CONF=/home/yiyiwang/.local/neo4j/conf/
  # $ neo4j-admin set-initial-password XXXXXX
  # $ neo4j start
  # $ cypher-shell
  # 
  # Then visit http://127.0.0.1:7474/browser/
  # * Host is neo4j://localhost:7687
  # * username will be `neo4j`, password will be XXXXXX that you set previously
  #
  # Also might need to fix the directory permissions if necessary.  
  # Sometimes might need to run `sudo rm /home/yiyiwang/.local/neo4j/logs/neo4j.log` to fix the issue.
}
