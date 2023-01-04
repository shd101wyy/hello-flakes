{ pkgs, ... }:
# This is the home configuration for yiyiwang's steam deck
{
  home.packages = with pkgs; [
    sl # An funny command
    crawl # Dungeon crawl stone soup
  ];
}
