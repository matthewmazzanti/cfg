{
  pkgs,
  system,
  inputs,
}: let
  nvimOverlay = pkgs.extend (self: super: {
    vimPlugins =
      super.vimPlugins
      // {
        vim-easyclip = super.vimUtils.buildVimPlugin {
          pname = "vim-easyclip";
          version = builtins.toString inputs.vim-easyclip.lastModified;
          src = inputs.vim-easyclip;
          dependencies = with super.vimPlugins; [vim-repeat];
        };
      };
  });
in {
  "nvim/root" = nvimOverlay.callPackage ./nvim {};
  "nvim/dev" = nvimOverlay.callPackage ./nvim {
    options = {
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
  };
  "nvim/test" = (nvimOverlay.callPackage ./nvim {
    options = {
      plugins = true;
      lsp = true;
      treesitter = true;
      ai = true;
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
        rust = true;
        shell = true;
      };
    };
  });
  "zsh/dev" = pkgs.callPackage ./zsh {};
  "short-pwd/default" = pkgs.callPackage ./short-pwd {};
  "direnv/dev" = pkgs.callPackage ./direnv {
    direnv = inputs.direnv-patched.packages.${system}.default;
  };
  "less/dev" = pkgs.callPackage ./less {};
}
