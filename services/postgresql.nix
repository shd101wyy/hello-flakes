{ pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    enableTCPIP = true;
    authentication = pkgs.lib.mkOverride 10 ''
      local all all trust
      host all all 127.0.0.1/32 trust
      host all all ::1/128 trust
    '';
    initialScript = pkgs.writeText "backend-initScript" ''
      CREATE ROLE monitoring WITH LOGIN PASSWORD 'monitoring' CREATEDB;
      CREATE DATABASE monitoring;
      GRANT ALL PRIVILEGES ON DATABASE monitoring TO monitoring;
    '';
  };
}
