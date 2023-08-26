{ pkgs, ... }:
# This file includes some common
{
  programs.zsh = {
    enable = true;
    initExtra = ''
      export PATH=$PATH:/usr/local/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.yarn/bin
      export XDG_DATA_DIRS=$XDG_DATA_DIRS:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share


      # Check if /etc/os-release exists and the name is SteamOS
      if [ -f /etc/os-release ] && grep -q 'NAME="SteamOS"' /etc/os-release; then
        # podman path
        export PATH=$PATH:$HOME/.local/podman/bin
      fi

      # For flatpak installed vscode, add alias of `code` command
      if [ -f "/var/lib/flatpak/exports/bin/com.visualstudio.code" ]; then
        alias code="flatpak run com.visualstudio.code --password-store=\"gnome\""
      fi

      # For NixOS
      if [ -f /etc/NIXOS ]; then
        # https://github.com/NixOS/nixpkgs/issues/189851
        # https://discourse.nixos.org/t/open-links-from-flatpak-via-host-firefox/15465/8
        systemctl --user import-environment PATH
        systemctl --user restart xdg-desktop-portal.service
      fi

      # direnv
      eval "$(direnv hook zsh)"

      # rust cargo home
      export CARGO_HOME="$HOME/.cargo"

      # set proxy env variables
      PORT=8889
      ## Curl reads and understands the following environment variables:
      export HTTP_PROXY=http://127.0.0.1:$PORT
      export HTTPS_PROXY=http://127.0.0.1:$PORT
      export http_proxy=http://127.0.0.1:$PORT
      export https_proxy=http://127.0.0.1:$PORT
      
      ## They should be set for protocol-specific proxies. General proxy should be set with
      export ALL_PROXY=socks://127.0.0.1:$PORT
      export all_proxy=socks://127.0.0.1:$PORT
      
      ## A comma-separated list of host names that shouldn't go through any proxy is set in (only an asterisk, '*' matches all hosts)
      export NO_PROXY=localhost,127.0.0.1,::1
      export no_proxy=localhost,127.0.0.1,::1
      
      # Alias commands
      alias view='vim -R'
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
    ];
    # settings = { ignorecase = true; };
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    # withNodeJs = true;
    # withPython3 = true;
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

  programs.doom-emacs = {
    enable = false;
    # Link to ../emacs/doom.d
    doomPrivateDir = builtins.getEnv("PWD") + "/emacs/doom.d";
  };
}
