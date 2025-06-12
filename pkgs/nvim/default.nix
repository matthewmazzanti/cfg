{
  pkgs,
  lib,
  stdenvNoCC,
  options ? {},
}: let
  inherit (lib) optionals;
  inherit (lib.strings) concatMapStringsSep;

  baseOptions = {
    plugins = false;
    treesitter = false;
    lsp = false;
    ai = false;
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

  packages = with pkgs; (
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

  grammars = grammars: with grammars; [
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
    starlark
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

        # Picker
        fzf-lua

        # Misc
        vim-fugitive # Git management
        vim-signature # Show marks
        vim-wordmotion # CamelCase and other motions
        vim-easyclip # Improved yank/delete buffer better
        vim-sandwich # Surround
        readline-vim # cli keybinds

        (stdenvNoCC.mkDerivation (ftplugin // {
          name = "ftplugin";
          passAsFile = builtins.attrNames ftplugin;
          buildCommand = ''
            mkdir -p "$out/ftplugin"
            for var in $passAsFile; do
              pathVar="''${var}Path"
              cp "''${!pathVar}" "$out/ftplugin/$var.lua"
            done
          '';
        }))
      ]
      ++ optionals opts.treesitter [
        # Treesitter
        (nvim-treesitter.withPlugins grammars)
        nvim-treesitter-textobjects # Treesitter powered textobjects
        nvim-ts-autotag # Auto XML/HTML tag closing
        treesj # Split/Join list structures
        # hop-nvim # Visual interactive jumps using treesitter
      ]
      ++ optionals opts.lsp [
        # Language server configurations
        nvim-lspconfig

        # Completion
        blink-cmp
      ]
      ++ optionals opts.ai [
        codecompanion-nvim
        mini-diff
      ]
      ++ optionals (opts.lsp && opts.ai) [
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
        ./config/fzf.lua
        ./config/easyclip.lua
      ]
      ++ optionals opts.treesitter [
        ./config/treesitter.lua
      ]
      ++ optionals opts.lsp [
        ./config/lspconfig.lua
        ./config/blink.lua
      ]
      ++ optionals opts.ai [
        ./config/codecompanion.lua
      ]
    );
in
  pkgs.callPackage ./wrapper.nix {
    packages = packages;
    plugins = plugins;
    init = ''
      local function safe_dofile(file)
        local ok, err = pcall(dofile, file)
        if not ok then
          vim.print(err)
        end
      end
    ''
    + (concatMapStringsSep "\n" (f: ''safe_dofile("${f}")'') init);
  }
