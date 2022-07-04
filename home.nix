{ pkgs, ... }:
# Run the following commands:
#  $ ln -s $PWD/home.nix $HOME/.config/nixpkgs/home.nix
#
{
  programs.zsh = {
    enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "ys";
    };
  };

  programs.git = {
    enable = true;
    userName = "shd101wyy";
    userEmail = "shd101wyy@gmail.com";
  };

  home.packages = with pkgs; [ ];
}
