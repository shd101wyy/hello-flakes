{ pkgs, ... }:
# This module is managed by Flakes
# Run the following commands build the configuration:
# $ nix build .\#homeConfigurations.yiyiwang-home.activationPackage
# 
{
  home.stateVersion = "22.05";
  home.username = "yiyiwang";
  home.homeDirectory = "/home/yiyiwang";

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
    extraConfig = {
      pull = {
        rebase = false;
        # ff = "only";
      };
    };
  };

  # https://nix-community.github.io/home-manager/options.html#opt-programs.neovim.enable
  programs.neovim = {
    enable = true;
    coc = {
      enable = true;
      settings = {};
    };
    plugins = with pkgs.vimPlugins; [
      YouCompleteMe
      coc-css
      coc-emmet
      coc-go
      coc-html
      coc-json
      coc-lua
      coc-nvim
      coc-python
      coc-rls
      coc-tailwindcss
      coc-tsserver
      coc-yaml
      copilot-vim
      ctrlp-vim
      nerdtree
      nerdtree-git-plugin
      orgmode
      rainbow
      syntastic
      vim-airline
      vim-fugitive
      vim-gitgutter
      vim-lsp
      vim-nix
      vim-plug
    ];
    extraPackages = with pkgs;
        [ git (python3.withPackages (ps: with ps; [ black isort pylint ])) ];
    # settings = { ignorecase = true; };
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;
    extraConfig = ''
" ~/.vimrc configuration

" Enable NERDTree on start
" autocmd VimEnter * NERDTree

" Enable line number
:set number
'';
  };

  home.packages = with pkgs; [ ];
  dconf.settings = {
    "org/gnome/mutter" = {
      experimental-features = [ "scale-monitor-framebuffer" ];
    };
  };
}
