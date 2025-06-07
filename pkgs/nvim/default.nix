{ pkgs, vim-easyclip, ... }: let
  # Add flake inputs as vim plugins
  # TODO: Upstream easyclip - or un-upstream everything?
  overlay = self: super: {
    vimPlugins = super.vimPlugins // {
      vim-easyclip = super.vimUtils.buildVimPlugin {
        pname = "vim-easyclip";
        version = builtins.toString vim-easyclip.lastModified;
        src = vim-easyclip;
        dependencies = with super.vimPlugins; [vim-repeat];
      };
    };
  };
in {
  "nvim/root" = overlay.callPackage ./root.nix {};
  "nvim/dev" = overlay.callPackage ./dev.nix {};
  "nvim/web" = overlay.callPackage ./web.nix {};
  "nvim/test" = overlay.callPackage ./test.nix {};
}
