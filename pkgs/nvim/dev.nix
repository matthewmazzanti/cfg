{
  # Nixpkgs functions
  callPackage
, writeText
, buildEnv
  # Vim stuff
, wrapNeovimUnstable
, neovim-unwrapped
, vimPlugins
  # Language servers
, gopls
, lua-language-server
, nodePackages
, rust-analyzer
, nil
, ccls
, ...
}:
let
  path = buildEnv {
    name = "nvim-path";
    paths = [
      gopls
      lua-language-server
      nodePackages.pyright
      nodePackages.typescript-language-server
      nil
      rust-analyzer
      ccls
    ];
  };

  ftplugin = callPackage ./config/ftplugin.nix { };

  plugins = with vimPlugins; [
    # Custom ftplugin stuff
    ftplugin
    vim-python-pep8-indent # Better python indent handling
    vim-nix # Basic nix stuff

    # Visual enhancements
    gruvbox-nvim
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

    # Completion
    nvim-cmp
    cmp-nvim-lsp
    cmp-buffer
    luasnip
    cmp_luasnip

    # Language servers
    nvim-lspconfig
    lsp_lines-nvim

    # Treesitter
    (nvim-treesitter.withPlugins (plugins: with plugins; [
      bash
      c
      css
      dockerfile
      go
      haskell
      html
      javascript
      json
      lua
      markdown
      nix
      python
      ruby
      typescript
      yaml
    ]))
    nvim-treesitter-textobjects # Treesitter powered textobjects
    nvim-ts-autotag # Auto XML/HTML tag closing
    treesj # Split/Join list structures
  ];

  init = writeText "init.lua" ''
    dofile("${./config/init.lua}")
    dofile("${./config/gruvbox.lua}")
    dofile("${./config/lualine.lua}")
    dofile("${./config/sandwich.lua}")
    dofile("${./config/telescope.lua}")
    dofile("${./config/treesitter.lua}")
    dofile("${./config/lspconfig.lua}")
    dofile("${./config/cmp.lua}")
    dofile("${./config/hop.lua}")
    dofile("${./config/treesj.lua}")
    dofile("${./config/easyclip.lua}")
  '';
in
wrapNeovimUnstable neovim-unwrapped {
  wrapRc = false;
  wrapperArgs = [
    # Add path item to wrapper
    "--suffix" "PATH" ":" ''${path}/bin''
    # Add generated init
    "--add-flags" ''-u ${init}''
  ];
  withPython3 = false;
  withNodeJs = false;
  withRuby = false;
  vimAlias = true;
  packpathDirs.myNeovimPackages = {
    start = plugins;
    opt = [ ];
  };
}
