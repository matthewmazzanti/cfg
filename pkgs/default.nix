{
  pkgs,
  system,
  inputs,
}: let
  inherit (pkgs.lib) recursiveUpdate;

  nvimOverlay = pkgs.extend (self: super: {
    vimPlugins =
      super.vimPlugins
      // {
        vim-easyclip = super.vimUtils.buildVimPlugin {
          pname = "vim-easyclip";
          version = toString inputs.vim-easyclip.lastModified;
          src = inputs.vim-easyclip;
          dependencies = with super.vimPlugins; [vim-repeat];
        };
      };
  });

  neovimOptions = {
    plugins = true;
    lsp = true;
    treesitter = true;
    ai = false;
    langs = {
      c = false;
      data = true;
      docs = true;
      go = true;
      haskell = false;
      web = true;
      lua = true;
      nix = true;
      python = true;
      rust = false;
      shell = true;
    };
  };

  nu = import ./nu/default.nix {
    inherit pkgs system inputs;
  };
in nu // {
  "nvim/root" = nvimOverlay.callPackage ./nvim {};
  "nvim/dev" = nvimOverlay.callPackage ./nvim {
    options = neovimOptions;
  };
  "nvim/ai" = (nvimOverlay.callPackage ./nvim {
    options = recursiveUpdate neovimOptions { ai = true; };
  });
  "nvim/nix" = nvimOverlay.callPackage ./nvim {
    options = {
      plugins = true;
      lsp = true;
      treesitter = true;
      langs = {
        nix = true;
        python = true;
      };
    };
  };
  "zsh/dev" = pkgs.callPackage ./zsh {};
  "direnv/dev" = pkgs.callPackage ./direnv {
    direnv = inputs.direnv-patched.packages.${system}.default;
  };
  "less/dev" = pkgs.callPackage ./less {};
  "ghostty/config" = pkgs.callPackage ./ghostty { inherit system; };
}
