{ pkgs, lib, config, ... }:
with lib;
let
  color = config.theme.color;
  root = ".config/nvim";
  ftplugin = "${root}/ftplugin";
in
{
  options = {
    theme = mkOption {
      type = types.attrs;
    };
  };

  config.programs.neovim = {
    enable = true;
    withNodeJs = true;

    extraConfig = with pkgs; ''
      " neovim lsp
      lua <<EOF
      local language_servers = {
        rust_analyzer = { "${rust-analyzer}/bin/rust-analyzer" },
        gopls = { "${gopls}/bin/gopls" },
        pylsp = { "${python3Packages.python-lsp-server}/bin/pylsp" },
        tsserver = {
          "${nodePackages.typescript-language-server}/bin/typescript-language-server",
          "--stdio"
        },
        hls = { "${haskell-language-server}/bin/haskell-language-server" },
        ccls = { "${ccls}/bin/ccls" },
        rnix = { "${rnix-lsp}/bin/rnix-lsp" },
        bashls = {
          "${nodePackages.bash-language-server}/bin/bash-language-server",
          "start"
        },
      }

      local sumneko_lua = "${sumneko-lua-language-server}/bin/lua-language-server"

      ${builtins.readFile ./init.lua}
      EOF

      ${builtins.readFile ./vimrc.vim}
    '';

    plugins = with pkgs.vimPlugins; [
      # Misc improvements
      fzfWrapper
      fzf-vim
      vim-closetag
      vim-easyclip
      # todo: used?
      vim-fugitive
      vim-sandwich
      vim-signature
      camelcasemotion

      # Visuals
      gruvbox-community
      lightline-vim

      # Syntax
      vim-pandoc-syntax
      vim-pgsql
      idris-vim
      rust-vim
      vim-glsl
      vim-python-pep8-indent

      # Tree sitter / LSP
      (nvim-treesitter.withPlugins (_: pkgs.tree-sitter.allGrammars))
      nvim-treesitter-textobjects
      nvim-lspconfig
      nvim-compe
    ];
  };

  config.home.file = {
    "${ftplugin}/javascript.vim".source = ./ft/two-space.vim;
    "${ftplugin}/typescript.vim".source = ./ft/two-space.vim;
    "${ftplugin}/html.vim".source = ./ft/two-space.vim;
    "${ftplugin}/css.vim".source = ./ft/two-space.vim;
    "${ftplugin}/json.vim".source = ./ft/two-space.vim;
    "${ftplugin}/yaml.vim".source = ./ft/two-space.vim;
    "${ftplugin}/nix.vim".source = ./ft/two-space.vim;
    "${ftplugin}/go.vim".source = ./ft/tab.vim;
    "${ftplugin}/c.vim".source = ./ft/tab.vim;
    "${ftplugin}/cpp.vim".source = ./ft/two-space.vim;
    "${ftplugin}/markdown.vim".text = ''
      ${builtins.readFile ./ft/two-space.vim}
      setlocal spell
    '';
    "${ftplugin}/python.vim".text = ''
      setlocal colorcolumn=80
    '';
  };

}
