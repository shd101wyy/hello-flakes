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
      # This is a bug in coc.nvim, so we have to manually set it for now
      package = pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "coc.nvim";
        version = "2022-06-14";
        src = pkgs.fetchFromGitHub {
          owner = "neoclide";
          repo = "coc.nvim";
          rev = "87e5dd692ec8ed7be25b15449fd0ab15a48bfb30";
          sha256 = "sha256-bsrCvgQqIA4jD62PIcLwYdcBM+YLLKLI/x2H5c/bR50=";
        };
        meta.homepage = "https://github.com/neoclide/coc.nvim/";
      };
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
