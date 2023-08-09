{ pkgs, ... }:
# This file includes some common
{
  programs.zsh = {
    enable = true;
    initExtra = ''
      export PATH=$PATH:/usr/local/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.yarn/bin

      # Check if /etc/os-release exists and the name is SteamOS
      if [ -f /etc/os-release ] && grep -q 'NAME="SteamOS"' /etc/os-release; then
        # For flatpak installed vscode, add alias of `code` command
        if [ -f "/var/lib/flatpak/exports/bin/com.visualstudio.code" ]; then
          alias code="/var/lib/flatpak/exports/bin/com.visualstudio.code"
        fi

        # podman path
        export PATH=$PATH:$HOME/.local/podman/bin
      fi

      # direnv
      eval "$(direnv hook zsh)"

      # rust cargo home
      export CARGO_HOME="$HOME/.cargo"
    '';

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "ys";
    };
  };

  programs.git = {
    enable = true;
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
      awesome-vim-colorschemes
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
      vim-airline-themes
      vim-codefmt
      vim-fugitive
      vim-gitgutter
      vim-lsp
      vim-multiple-cursors
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
    # withNodeJs = true;
    withPython3 = true;
    extraConfig = ''
      " ~/.vimrc configuration

      " Enable NERDTree on start
      " autocmd VimEnter * NERDTree

      " Enable line number
      set number

      " Keymaps
      map <silent> <C-b> :NERDTreeToggle<CR>

      " Airline theme
      let g:airline_theme='papercolor'
      set background=dark
      colorscheme PaperColor
    '';
  };

  # programs.alacritty = { enable = true; };
}
