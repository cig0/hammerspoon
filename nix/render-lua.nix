{ lib }:

let
  render = value:
    if value == null then
      "nil"
    else if builtins.isBool value then
      if value then "true" else "false"
    else if builtins.isString value then
      builtins.toJSON value
    else if builtins.isInt value || builtins.isFloat value then
      toString value
    else if builtins.isList value then
      "{ ${lib.concatMapStringsSep ", " render value} }"
    else if builtins.isAttrs value then
      let
        fields = lib.mapAttrsToList (
          name: item: "[${builtins.toJSON name}] = ${render item}"
        ) value;
      in
      "{ ${lib.concatStringsSep ", " fields} }"
    else
      throw "Cannot render this Nix value as Lua";
in
render
