{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Plugins
    vim-easyclip.url = "github:svermeulen/vim-easyclip/master";
    vim-easyclip.flake = false;
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
