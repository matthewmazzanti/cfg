{
  pkgs,
  lib,
  options ? {},
}: let
  inherit (lib) optionals;

  baseOptions = {
    plugins = false;
    treesitter = false;
    lsp = false;
    copilot = false;
    langs = {
      c = false;
      data = false;
      docs = false;
      go = false;
      haskell = false;
      web = false;
      lua = false;
      nix = false;
      python = false;
      rust = false;
      shell = false;
    };
  };

  opts = lib.attrsets.recursiveUpdate baseOptions options;

  paths = with pkgs; (
    [fd]
    ++ optionals (opts.plugins && opts.lsp) (
      optionals opts.langs.c [ccls]
      ++ optionals opts.langs.go [gopls]
      ++ optionals opts.langs.haskell [haskell-language-server]
      ++ optionals opts.langs.web [nodePackages.typescript-language-server]
      ++ optionals opts.langs.lua [lua-language-server]
      ++ optionals opts.langs.nix [nil]
      ++ optionals opts.langs.python [pyright]
      ++ optionals opts.langs.rust [rust-analyzer]
      ++ optionals opts.langs.shell [bash-language-server]
    )
  );

  grammars = grammars:
    with grammars; [
      # Seem interesting, but not that useful
      # git-config git-rebase gitattributes gitcommit gitignore
      bash
      c
      cpp
      css
      csv
      diff
      go
      haskell
      html
      html
      htmldjango
      ini
      javascript
      json
      json5
      lua
      markdown
      nix
      python
      rst
      rust
      sql
      toml
      tsv
      tsx
      typescript
      vimdoc
      xml
      yaml
    ];

  plugins = with pkgs.vimPlugins;
    [
      gruvbox-nvim
    ]
    ++ optionals opts.plugins (
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
        # readline-vim # cli keybinds
        # hop-nvim # Visual interactive jumps using treesitter

        # Telescope
        telescope-nvim
        telescope-fzf-native-nvim
      ]
      ++ optionals opts.treesitter [
        # Treesitter
        (nvim-treesitter.withPlugins grammars)
        nvim-treesitter-textobjects # Treesitter powered textobjects
        nvim-ts-autotag # Auto XML/HTML tag closing
        treesj # Split/Join list structures
      ]
      ++ optionals opts.lsp [
        # Language server configurations
        nvim-lspconfig

        # Completion
        # nvim-cmp cmp-nvim-lsp cmp-buffer luasnip cmp_luasnip
        blink-cmp
      ]
      ++ optionals (opts.lsp && opts.copilot) [
        copilot-lua
        blink-copilot
      ]
    );

  init =
    [
      ./config/init.lua
      ./config/gruvbox.lua
    ]
    ++ optionals opts.plugins (
      [
        ./config/lualine.lua
        ./config/sandwich.lua
        ./config/telescope.lua
        ./config/easyclip.lua
      ]
      ++ optionals opts.treesitter [
        ./config/treesitter.lua
        ./config/treesj.lua
      ]
      ++ optionals opts.lsp [
        ./config/lspconfig.lua
        # ./config/cmp.lua
        ./config/blink.lua
      ]
    );

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

    # Two-space languages
    cpp = two-space;
    css = two-space;
    h = two-space;
    hcl = two-space;
    html = two-space;
    htmldjango = two-space;
    javascript = two-space;
    javascriptreact = two-space;
    json = two-space;
    # Use vim :help for Lua files
    lua = ''
      ${two-space}
      vim.opt_local.keywordprg = ""
    '';
    markdown = ''
      ${two-space}
      -- vim.opt_local.spell = true
      -- vim.opt_local.colorcolumn = "89"
      -- vim.opt_local.textwidth = 88
    '';
    nix = two-space;
    terraform = two-space;
    typescript = two-space;
    typescriptreact = two-space;
    yaml = two-space;
  };
in
  pkgs.callPackage ./wrapper.nix {
    inherit paths init plugins ftplugin;
  }
