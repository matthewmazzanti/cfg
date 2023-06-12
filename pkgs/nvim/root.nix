{ callPackage
, writeText
, wrapNeovimUnstable
, neovim-unwrapped
, vimPlugins
, ...
}:
let
  inherit (builtins) readFile;

  ftplugin = callPackage ./config/ftplugin.nix { };

  init = writeText "init.lua" ''
    ${readFile ./config/init.lua}
    ${readFile ./config/gruvbox.lua}
  '';
in
wrapNeovimUnstable neovim-unwrapped {
  wrapRc = false;
  wrapperArgs = [ "--add-flags" ''-u ${init}'' ];
  withPython3 = false;
  withNodeJs = false;
  withRuby = false;
  vimAlias = true;
  packpathDirs.myNeovimPackages = {
    start = with vimPlugins; [
      ftplugin
      vim-python-pep8-indent
      vim-nix
      gruvbox-nvim
    ];
    opt = [ ];
  };
}
