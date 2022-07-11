{ pkgs, ... }:
# Run the following commands:
#  $ ln -s $PWD/home.nix $HOME/.config/nixpkgs/home.nix
#
# To switch to this configuration, run (no need to sudo):
#  $ home-manager switch
{
  programs.zsh = {
    enable = true;
    initExtra = ''
      export PATH=$PATH:/usr/local/bin:$HOME/.local/bin
      eval "$(direnv hook zsh)"
    '';

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
  dconf.settings = {
    "org/gnome/mutter" = {
      experimental-features = [ "scale-monitor-framebuffer" ];
    };
  };
}
