{ pkgs, lib, ... }:
# This file includes some common
{
  programs.zsh = {
    enable = true;
    initContent = ''
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

      # Add debugCommand directory to PATH if it exists
      if [ -d "$HOME/.var/app/com.visualstudio.code/config/Code/User/globalStorage/github.copilot-chat/debugCommand" ]; then
        export PATH="$PATH:$HOME/.var/app/com.visualstudio.code/config/Code/User/globalStorage/github.copilot-chat/debugCommand"
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

      export RUST_BACKTRACE=1

      # Configure direnv
      mkdir -p ~/.config/direnv/

      if [ ! -f "$HOME/.config/direnv/direnv.toml" ]; then
        cat > "$HOME/.config/direnv/direnv.toml" <<'EOF'
    [global]
    log_format = "-"
    log_filter = "^$"
    EOF
      fi
      

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
    # defaultEditor = true;
    coc = {
      enable = true;
      settings = { };
    };
    plugins = with pkgs.vimPlugins; [
      awesome-vim-colorschemes
      barbar-nvim
      barbecue-nvim
      coc-css
      coc-emmet
      coc-go
      coc-html
      coc-json
      coc-lua
      coc-nvim
      # coc-python
      coc-rls
      coc-tailwindcss
      coc-tsserver
      coc-yaml
      copilot-vim
      ctrlp-vim
      nvim-tree-lua
      nvim-treesitter
      nvim-treesitter.withAllGrammars
      nvim-web-devicons
      orgmode
      rainbow
      syntastic
      telescope-nvim
      vim-airline
      vim-airline-themes
      vim-codefmt
      vim-fugitive
      vim-gitgutter
      vim-illuminate
      vim-lsp
      vim-multiple-cursors
      vim-nix
      vim-plug
      YouCompleteMe
    ];
    extraPackages = with pkgs; [
    ];
    # settings = { ignorecase = true; };
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    # withNodeJs = true;
    # withPython3 = true;
    extraConfig = builtins.readFile ../nvim/init.vim;
    extraLuaConfig = builtins.readFile ../nvim/init.lua;
  };

  ## programs.doom-emacs = {
  ##   enable = false;
  ##   # Link to ../emacs/doom.d
  ##   doomPrivateDir = builtins.getEnv ("PWD") + "/emacs/doom.d";
  ## };

  programs.helix = {
    enable = true;
    settings = {
      # https://github.com/helix-editor/helix/tree/master/runtime/themes
      theme = "github_dark";
      editor.cursor-shape = {
        normal = "block";
        insert = "bar";
        select = "underline";
      };
    };
    languages.language = [
      {
        name = "nix";
        auto-format = true;
        formatter.command = lib.getExe pkgs.nixfmt-rfc-style;
      }
    ];
    themes = {
      autumn_night_transparent = {
        "inherits" = "autumn_night";
        "ui.background" = { };
      };
    };
  };
}
