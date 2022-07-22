{ pkgs, ... }:
# This module is managed by Flakes
# Run the following commands build the configuration:
# $ nix build .\#homeConfigurations.yiyiwang-home.activationPackage
# $ "$(nix path-info .\#homeConfigurations.yiyiwang-home.activationPackage)"/activate 
# To get the SHA256
# nix-prefetch fetchFromGitHub --owner owner --repo repo --rev 65bb66d364e0d10d00bd848a3d35e2755654655b
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
      settings = { };
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
      vim-codefmt
      vim-fugitive
      vim-gitgutter
      vim-lsp
      vim-nix
      vim-plug
    ];
    extraPackages = with pkgs; [
      git
      (python3.withPackages (ps: with ps; [ black isort pylint ]))
      nixpkgs-fmt
    ];
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

      " Keymaps
      map <silent> <C-b> :NERDTreeToggle<CR>
    '';
  };

  programs.alacritty = {
    enable = true;
  };

  home.packages = with pkgs; [ ];
  dconf.settings = {
    "org/gnome/mutter" = {
      experimental-features = [ "scale-monitor-framebuffer" ];
    };
  };
}
