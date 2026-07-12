{
  pkgs,
  system,
  inputs,
}: let
  neovimOptions = {
    plugins = true;
    lsp = true;
    treesitter = true;
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

in {
  "nvim/root" = pkgs.callPackage ./nvim {};
  "nvim/dev" = pkgs.callPackage ./nvim {
    options = neovimOptions;
  };
  "nvim/nix" = pkgs.callPackage ./nvim {
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
