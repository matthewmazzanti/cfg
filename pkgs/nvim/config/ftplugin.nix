{ stdenvNoCC, ... }:
let
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

  ftplugin = {
    # Tab based languages
    go = tab;
    c = tab;

    # Four space languages
    python = ''
      vim.opt_local.colorcolumn = "80"
      vim.opt_local.textwidth = 79
    '';
    # Use vim :help for Lua files
    lua = ''
      vim.opt_local.keywordprg = ""
    '';

    # Two-space languages
    javascript = two-space;
    typescript = two-space;
    html = two-space;
    css = two-space;
    json = two-space;
    yaml = two-space;
    nix = two-space;
    cpp = two-space;
    h = two-space;
    terraform = two-space;
    hcl = two-space;
    markdown = ''
      ${two-space}
      vim.opt_local.spell = true
    '';
  };
in
stdenvNoCC.mkDerivation (ftplugin // {
  name = "ftplugin";
  passAsFile = builtins.attrNames ftplugin;
  buildCommand = ''
    mkdir -p "$out/ftplugin"
    for var in $passAsFile; do
        pathVar="''${var}Path"
        cat "''${!pathVar}" > "$out/ftplugin/$var.lua"
    done
  '';
})
