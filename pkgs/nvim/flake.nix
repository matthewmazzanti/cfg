{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Neovim
    vim-easyclip-src = {
      url = "github:svermeulen/vim-easyclip/master";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    with flake-utils.lib;
    eachSystem defaultSystems (system:
      let
        # Add flake inputs as vim plugins
        # TODO: Upstream easyclip - or un-upstream everything?
        nvimOverlay = _: super:
          let
            buildPlugin = super.vimUtils.buildVimPluginFrom2Nix;
            versionOf = src: builtins.toString src.lastModified;
          in
          {
            vimPlugins = super.vimPlugins // {
              vim-easyclip = buildPlugin {
                pname = "vim-easyclip";
                version = versionOf inputs.vim-easyclip-src;
                src = inputs.vim-easyclip-src;
                dependencies = with super.vimPlugins; [ vim-repeat ];
              };
            };
          };

        pkgs = nixpkgs.legacyPackages.${system}.extend nvimOverlay;
      in {
        packages.nvim = pkgs.writeShellScriptBin "testing" ''
          echo "hello world"
        '';
      }
    );
}
