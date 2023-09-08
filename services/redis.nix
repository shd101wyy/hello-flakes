{ pkgs, ... }:

{
  services.redis.package = pkgs.redis;
  services.redis.servers = {
    "master" = {
      enable = true;
      port = 6379;
      # requirePassFile = "/home/yiyiwang/.credentials/redis-password";
      # requirePass = "foobared";
      requirePass = null;
      settings = {
        appendonly = "yes";
        "cluster-enabled" = "yes";
      };
    };
    "slave1" = {
      enable = true;
      port = 6380;
      # requirePassFile = "/home/yiyiwang/.credentials/redis-password";
      # requirePass = "foobared";
      requirePass = null;
      slaveOf = {
        ip = "0.0.0.0";
        port = 6379;
      };
      settings = {
        appendonly = "yes";
      };
    };
  };
}
