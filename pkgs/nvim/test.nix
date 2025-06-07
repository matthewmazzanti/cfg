{ pkgs
, lib
, options? {}
, ...
}: let
  inherit (lib) optionals;

  baseOptions = {
    plugins = false;
    lsp = false;
    treesitter = false;
    langs = {
      c = false;
      data = false;
      docs = false;
      go = false;
      # haskell = false;
      javascript = false;
      lua = false;
      nix = false;
      python = false;
      rust = false;
      shell = false;
    };
  };

  opts = lib.attrsets.recursiveUpdate baseOptions options;

  paths = with pkgs; (
    [ fd ] ++
    optionals (opts.plugins && opts.lsp) (
      optionals opts.langs.c      [ ccls ] ++
      optionals opts.langs.go     [ gopls ] ++
      # optionals opts.langs.hakell [ haskell-language-server ] ++
      optionals opts.langs.web    [ nodePackages.typescript-language-server ] ++
      optionals opts.langs.lua    [ lua-language-server ] ++
      optionals opts.langs.nix    [ nil ] ++
      optionals opts.langs.python [ pyright ] ++
      optionals opts.langs.rust   [ rust-analyzer ] ++
      optionals opts.langs.shell  [ bash-language-server ]
    )
  );

  grammars = (grammars: with grammars; (
    optionals opts.langs.c       [ c cpp ] ++
    optionals opts.langs.data    [ json xml yaml tsv csv ] ++
    optionals opts.langs.docs    [ markdown vimdoc rst ] ++
    optionals opts.langs.go      [ go ] ++
    # optionals opts.langs.haskell [ haskell ] ++
    optionals opts.langs.web     [
      html html htmldjango
      javascript typescript tsx
      css
    ] ++
    optionals opts.langs.lua     [ lua ] ++
    optionals opts.langs.nix     [ nix ] ++
    optionals opts.langs.python  [ python ] ++
    optionals opts.langs.shell   [ bash ] ++
    optionals opts.langs.rust    [ rust ]
  ));

  plugins = (with pkgs.vimPlugins; [
    gruvbox-nvim
  ] ++
  optionals opts.plugins (
    [
      vim-python-pep8-indent # Better python indent handling
      vim-nix # Basic nix stuff

      # Visual enhancements
      lualine-nvim

      vim-fugitive # Git management
      vim-signature # Show marks
      vim-wordmotion # CamelCase and other motions
      vim-easyclip # Improved yank/delete buffer better
      vim-sandwich # Surround
      # hop-nvim # Visual interactive jumps using treesitter

      # Telescope
      telescope-nvim
      telescope-fzf-native-nvim
    ] ++
    optionals opts.lsp [
      # Completion
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      luasnip
      cmp_luasnip

      # Language servers
      nvim-lspconfig
    ] ++
    optionals opts.treesitter [
      # Treesitter
      (nvim-treesitter.withPlugins grammars)
      nvim-treesitter-textobjects # Treesitter powered textobjects
      nvim-ts-autotag # Auto XML/HTML tag closing
      treesj # Split/Join list structures
    ]
  ));

  init = ([
    ./config/init.lua
    ./config/gruvbox.lua
  ] ++
  optionals opts.plugins (
    [
      ./config/lualine.lua
      ./config/sandwich.lua
      ./config/telescope.lua
      ./config/easyclip.lua
    ] ++
    optionals opts.lsp [
      ./config/lspconfig.lua
      ./config/cmp.lua
    ] ++
    optionals opts.treesitter [
      ./config/treesitter.lua
      ./config/treesj.lua
    ]
  ));

  ftplugin = let
    two-space = ''
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.softtabstop = 2
      vim.opt_local.expandtab = true
    '';

    tab = ''
      vim.opt_local.tabstop = 8
      vim.opt_local.shiftwidth = 8
      vim.opt_local.softtabstop = 0
      vim.opt_local.expandtab = false
    '';

  in {
    # Tab based languages
    go = tab;
    c = tab;

    # Four space languages
    python = ''
      vim.opt_local.colorcolumn = "89"
      vim.opt_local.textwidth = 88
    '';
    # Use vim :help for Lua files
    lua = ''
      vim.opt_local.keywordprg = ""
    '';

    # Two-space languages
    javascript = two-space;
    typescript = two-space;
    javascriptreact = two-space;
    typescriptreact = two-space;
    html = two-space;
    htmldjango = two-space;
    css = two-space;
    json = two-space;
    yaml = two-space;
    nix = two-space;
    cpp = two-space;
    h = two-space;
    terraform = two-space;
    hcl = two-space;
    markdown = ''
      ${two-space}
      vim.opt_local.spell = true
      vim.opt_local.colorcolumn = "89"
      vim.opt_local.textwidth = 88
    '';
  };
in pkgs.callPackage ./wrapper.nix {
  inherit paths init plugins ftplugin;
}
