{ lib, ... }:

let
  ensureListOfStrings = key: value:
    if builtins.isString value then [ value ]
    else if builtins.isList value && lib.all builtins.isString value then value
    else throw "ghostty-format: value for '${key}' must be a string or list of strings";

  formatKeyValue = key: value: let
    values = ensureListOfStrings key value;
    lines = map (value: "${key} = ${value}") values;
  in
    lib.concatStringsSep "\n" lines;

  # format :: AttrSet (String | [String]) -> String
  format = attrs: let
    blocks = lib.mapAttrsToList formatKeyValue attrs;
  in
    lib.concatStringsSep "\n" blocks + "\n";

  paletteMap = {
    black = 0;   bright-black = 8;
    red = 1;     bright-red = 9;
    green = 2;   bright-green = 10;
    yellow = 3;  bright-yellow = 11;
    blue = 4;    bright-blue = 12;
    magenta = 5; bright-magenta = 13;
    cyan = 6;    bright-cyan = 14;
    white = 7;   bright-white = 15;
  };

  # formatPalette :: AttrSet String -> [String]
  formatPalette = attrs:
    lib.mapAttrsToList (name: hex:
      let num = paletteMap.${name};
      in "${toString num}=${hex}"
    ) attrs;

  # formatKeybinds :: AttrSet String -> [String]
  formatKeybinds = attrs:
    lib.mapAttrsToList (key: value: "${key}=${value}") attrs;

  # quote :: String -> String
  quote = s: ''"${s}"'';

in { inherit format formatPalette formatKeybinds quote; }
