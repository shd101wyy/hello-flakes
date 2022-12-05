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

  manual.manpages.enable = false;

  programs.zsh = {
    enable = true;
    initExtra = ''
      export PATH=$PATH:/usr/local/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.yarn/bin
      eval "$(direnv hook zsh)"

      NIX_LINK=$HOME/.nix-profile

      # Set $NIX_SSL_CERT_FILE so that Nixpkgs applications like curl work.
      if [ -e /etc/ssl/certs/ca-certificates.crt ]; then # NixOS, Ubuntu, Debian, Gentoo, Arch
          export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
      elif [ -e /etc/ssl/ca-bundle.pem ]; then # openSUSE Tumbleweed
          export NIX_SSL_CERT_FILE=/etc/ssl/ca-bundle.pem
      elif [ -e /etc/ssl/certs/ca-bundle.crt ]; then # Old NixOS
          export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
      elif [ -e /etc/pki/tls/certs/ca-bundle.crt ]; then # Fedora, CentOS
          export NIX_SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt
      elif [ -e "$NIX_LINK/etc/ssl/certs/ca-bundle.crt" ]; then # fall back to cacert in Nix profile
          export NIX_SSL_CERT_FILE="$NIX_LINK/etc/ssl/certs/ca-bundle.crt"
      elif [ -e "$NIX_LINK/etc/ca-bundle.crt" ]; then # old cacert in Nix profile
          export NIX_SSL_CERT_FILE="$NIX_LINK/etc/ca-bundle.crt"
      fi

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

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhsWithPackages (ps: with ps; [ rustup zlib glibc ]);
  };

  home.packages = with pkgs; [ ];
  dconf.settings = {
    "org/gnome/mutter" = {
      experimental-features = [ "scale-monitor-framebuffer" ];
    };
  };
}
