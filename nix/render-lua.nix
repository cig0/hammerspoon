{ lib }:

let
  inherit (lib)
    any
    concatStringsSep
    init
    last
    stringToCharacters
    ;

  renderNumber =
    value:
    let
      s = toString value;
      chars = stringToCharacters s;
      hasDot = any (c: c == ".") chars;

      trimTrailingZeros = chars: if last chars == "0" then trimTrailingZeros (init chars) else chars;

      trimTrailingDot = chars: if last chars == "." then init chars else chars;
    in
    if !hasDot then s else concatStringsSep "" (trimTrailingDot (trimTrailingZeros chars));

  render =
    value:
    if value == null then
      "nil"
    else if builtins.isBool value then
      if value then "true" else "false"
    else if builtins.isString value then
      builtins.toJSON value
    else if builtins.isInt value || builtins.isFloat value then
      renderNumber value
    else if builtins.isList value then
      "{ ${lib.concatMapStringsSep ", " render value} }"
    else if builtins.isAttrs value then
      let
        fields = lib.mapAttrsToList (name: item: "[${builtins.toJSON name}] = ${render item}") value;
      in
      "{ ${lib.concatStringsSep ", " fields} }"
    else
      throw "Cannot render this Nix value as Lua";
in
render
