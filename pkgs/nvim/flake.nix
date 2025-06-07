{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";

    # Plugins
    vim-easyclip.url = "github:svermeulen/vim-easyclip/master";
    vim-easyclip.flake = false;
  };

  outputs = {nixpkgs, ...} @ inputs: let
    inherit (import ../../lib nixpkgs) eachSystemOverlay;

    versionOf = src: builtins.toString src.lastModified;

    # Add flake inputs as vim plugins
    # TODO: Upstream easyclip - or un-upstream everything?
    nvimOverlay = self: super: {
      vimPlugins =
        super.vimPlugins
        // {
          vim-easyclip = super.vimUtils.buildVimPlugin {
            pname = "vim-easyclip";
            version = versionOf inputs.vim-easyclip;
            src = inputs.vim-easyclip;
            dependencies = with super.vimPlugins; [vim-repeat];
          };
        };
    };
  in {
    packages = eachSystemOverlay nvimOverlay ({pkgs, ...}: {
      root = pkgs.callPackage ./root.nix {};
      dev = pkgs.callPackage ./dev.nix {};
      web = pkgs.callPackage ./web.nix {};
      test = pkgs.callPackage ./test.nix {};
    });
  };
}
