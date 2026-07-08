{
  pkgs,
  lib,
  system,
  stdenvNoCC,
  options ? {},
}: let
  inherit (lib) optionals;
  inherit (lib.strings) concatMapStringsSep;

  isLinux = lib.hasSuffix "linux" system;

  baseOptions = {
    plugins = false;
    treesitter = false;
    lsp = false;
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
    [
      fd
    ] ++ optionals isLinux [
      inotify-tools
    ]
    ++ optionals (opts.plugins && opts.lsp) (
      optionals opts.langs.c [ccls]
      ++ optionals opts.langs.go [gopls]
      ++ optionals opts.langs.haskell [haskell-language-server]
      ++ optionals opts.langs.web [typescript-language-server]
      ++ optionals opts.langs.lua [lua-language-server]
      ++ optionals opts.langs.nix [nixd]
      ++ optionals opts.langs.python [pyright]
      ++ optionals opts.langs.rust [rust-analyzer]
      ++ optionals opts.langs.shell [bash-language-server]
    )
  );

  ftplugin = let
    four-space = ''
      vim.opt_local.tabstop = 4
      vim.opt_local.shiftwidth = 4
      vim.opt_local.softtabstop = 4
      vim.opt_local.expandtab = true
    '';

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
      ${four-space}
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

      -- Skip vim's overrides for 4 spaces indent, breaks list formatting
      vim.g.markdown_recommended_style = 0

      -- Try to detect floating LSP windows
      -- May be a better option if https://github.com/neovim/neovim/issues/31206
      -- makes any progress
      if vim.bo.bufhidden ~= "wipe" then
        vim.opt_local.spell = true
        vim.opt_local.colorcolumn = "89"
        vim.opt_local.textwidth = 88
        vim.opt_local.wrap = true
      end
    '';
    nix = two-space;
    nu = four-space;
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
    htmldjango
    ini
    javascript
    json
    json5
    lua
    nix
    nu
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
        render-markdown-nvim

        # Picker
        fzf-lua

        # Misc
        vim-fugitive # Git management
        vim-signature # Show marks
        nvim-spider # CamelCase and other motions
        vim-easyclip # Improved yank/delete buffer better
        nvim-surround # Surround
        fidget-nvim

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

        # My own utils, factored as a plugin. `require("utils.whatever")`
        (stdenvNoCC.mkDerivation {
          name = "utils";
          buildCommand = ''
            mkdir -p "$out/lua"
            cp -r ${./plugin} "$out/lua/utils"
          '';
        })
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
        blink-cmp
      ]
    );

  init =
    [
      ./config/init.lua
      ./config/autoread.lua
      ./config/gruvbox.lua
      # Plugin-free (fugitive/fzf-lua degrade gracefully), so it loads in every
      # variant including the plugin-less root nvim. After gruvbox for the palette.
      ./config/statusline.lua
    ]
    ++ optionals opts.plugins (
      [
        ./config/input.lua
        ./config/fidget.lua
        ./config/surround.lua
        ./config/fzf.lua
        ./config/easyclip.lua
        ./config/spider.lua
        ./config/markdown.lua
        ./config/readline.lua
      ]
      ++ optionals opts.treesitter [
        ./config/treesitter.lua
      ]
      ++ optionals opts.lsp [
        ./config/lspconfig.lua
        ./config/blink.lua
      ]
    );
in
  pkgs.callPackage ./wrapper.nix {
    wrapperName = "nvim";
    aliases = ["vim"];
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
