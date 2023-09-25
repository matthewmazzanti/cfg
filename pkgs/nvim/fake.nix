{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Plugins
    vim-easyclip.url = "github:svermeulen/vim-easyclip/master";
    vim-easyclip.flake = false;

    nvim-ts-autotag.url = "github:matthewmazzanti/nvim-ts-autotag/main";
    nvim-ts-autotag.flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    with flake-utils.lib;
    eachSystem defaultSystems (system:
      let
        # Add flake inputs as vim plugins
        # TODO: Upstream easyclip - or un-upstream everything?
        nvimOverlay = _: super:
          let
            versionOf = src: builtins.toString src.lastModified;
            buildPlugin = super.vimUtils.buildVimPlugin;
          in
          {
            vimPlugins = super.vimPlugins // {
              vim-easyclip = buildPlugin {
                pname = "vim-easyclip";
                version = versionOf inputs.vim-easyclip;
                src = inputs.vim-easyclip;
                dependencies = with super.vimPlugins; [ vim-repeat ];
              };

              nvim-ts-autotag = buildPlugin {
                pname = "nvim-ts-autotag";
                version = versionOf inputs.nvim-ts-autotag;
                src = inputs.nvim-ts-autotag;
              };
            };

            tree-sitter = super.tree-sitter.override {
              extraGrammars = {
                starlark = super.tree-sitter.buildGrammar {
                  language = "starlark";
                  version = versionOf inputs.tree-sitter-starlark;
                  src = inputs.tree-sitter-starlark;
                };
              };
            };
          };

        pkgs = nixpkgs.legacyPackages.${system}.extend nvimOverlay;
      in
      {
        packages.root = pkgs.callPackage ./root.nix { };
        packages.dev = pkgs.callPackage ./dev.nix { };
        packages.web = pkgs.callPackage ./web.nix { };
      }
    );
}
