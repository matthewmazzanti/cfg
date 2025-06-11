{
  # Imports
  lib,
  lndir,
  makeWrapper,
  neovim-unwrapped,
  neovimUtils,
  stdenvNoCC,
  writeText,

  # Config
  packages? [],
  plugins? [],
  init ? "",
  vimAlias ? false,
}: let
  # inherit interpreter from neovim
  normalizedPlugins = neovimUtils.normalizePlugins plugins;

  finalPackdir = neovimUtils.packDir {
    vimPackage = neovimUtils.normalizedPluginsToVimPackage normalizedPlugins;
  };

  runtimeDeps = let
    getPluginDeps = p: p.plugin.runtimeDeps or [];
    pluginDeps = lib.lists.concatMap getPluginDeps normalizedPlugins;
  in pluginDeps ++ packages;

  initLua = writeText "init.lua" ''
    vim.opt.packpath:prepend("${finalPackdir}")
    vim.opt.runtimepath:prepend("${finalPackdir}")
    ${init}
  '';
in stdenvNoCC.mkDerivation ({
  name = "neovim";
  pname = "nvim";
  version = lib.getVersion neovim-unwrapped;

  nativeBuildInputs = [
    makeWrapper
    lndir
  ];

  dontUnpack = true;
  preferLocalBuild = true;

  buildPhase = ''
    runHook preBuild

    echo "Looking for lua dependencies..."
    source ${neovim-unwrapped.lua}/nix-support/utils.sh
    _addToLuaPath "${finalPackdir}"
    echo "LUA_PATH towards the end of packdir: $LUA_PATH"

    mkdir -p "$out"
    lndir -silent "${neovim-unwrapped}" "$out"
    unlink "$out/bin/nvim"
    makeWrapper ${neovim-unwrapped}/bin/nvim "$out/bin/nvim" \
      --suffix PATH ':' "${lib.makeBinPath runtimeDeps}" \
      --prefix LUA_PATH ';' "$LUA_PATH" \
      --prefix LUA_CPATH ';' "$LUA_CPATH" \
      --add-flags '-u ${initLua}'
  ''
  + lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
    rm $out/share/applications/nvim.desktop
    substitute ${neovim-unwrapped}/share/applications/nvim.desktop "$out/share/applications/nvim.desktop" \
      --replace-warn 'Name=Neovim' 'Name=Neovim wrapper'
  ''
  + lib.optionalString vimAlias ''
    ln -s "nvim" "$out/bin/vim"
  ''
  + ''
    runHook postBuild
  '';

  dontFixup = true;
})
