{ pkgs, ... }:

{
  services.redis.package = pkgs.redis;
  services.redis.servers = {
    "instance1" = {
      enable = true;
      port = 6379;
      requirePassFile = "/home/yiyiwang/redis-password";
    };
    "instance2" = {
      enable = true;
      port = 6380;
      requirePassFile = "/home/yiyiwang/redis-password";
    };
  };
}
