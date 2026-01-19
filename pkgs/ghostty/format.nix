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

in format
