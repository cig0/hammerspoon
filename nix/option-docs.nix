{
  lib,
  namespace ? "programs.hammerspoon-spoons",
  options ? import ./options.nix { inherit lib; },
}:

let
  inherit (lib)
    any
    concatStringsSep
    filter
    length
    mapAttrsToList
    optionalString
    replaceStrings
    take
    ;

  isOption = x: builtins.isAttrs x && x._type or null == "option";

  walk =
    prefix: value:
    if isOption value then
      [
        {
          path = prefix;
          option = value;
        }
      ]
    else if builtins.isAttrs value then
      lib.concatLists (mapAttrsToList (name: child: walk (prefix ++ [ name ]) child) value)
    else
      [ ];

  pathMatchesPrefix =
    prefix: path: length prefix <= length path && take (length prefix) path == prefix;

  filterEntries =
    exclude: entries:
    if exclude == [ ] then
      entries
    else
      filter (
        entry:
        !any (
          excludeSpec:
          pathMatchesPrefix (
            if builtins.isList excludeSpec then excludeSpec else lib.splitString "." excludeSpec
          ) entry.path
        ) exclude
      ) entries;

  typeDescription =
    option:
    if option.type ? description then
      option.type.description
    else if option.type ? name then
      option.type.name
    else
      "unknown";

  defaultValue =
    option:
    if option ? defaultText then
      "(expression)"
    else if option ? default then
      let
        s = builtins.toJSON option.default;
      in
      if s == "\"\"" then "`\"\"`" else "`${s}`"
    else
      "—";

  descriptionValue =
    option: optionalString (option ? description) (replaceStrings [ "\n" ] [ " " ] option.description);

  pathString = path: concatStringsSep "." path;

  markdownHeader = ''
    | Option | Type | Default | Description |
    |--------|------|---------|-------------|'';

  formatRow =
    { path, option }:
    "| `${namespace}.${pathString path}` | ${typeDescription option} | ${defaultValue option} | ${descriptionValue option} |";

  formatRowForNamespace =
    newNamespace:
    { path, option }:
    "| `${newNamespace}.${pathString path}` | ${typeDescription option} | ${defaultValue option} | ${descriptionValue option} |";

  allEntries = walk [ ] options;
in
{
  inherit allEntries markdownHeader;

  markdown = entries: concatStringsSep "\n" ([ markdownHeader ] ++ (map formatRow entries));

  markdownForNamespace =
    {
      newNamespace,
      includeHeader ? true,
      exclude ? [ ],
    }:
    let
      entries = filterEntries exclude allEntries;
      rows = map (formatRowForNamespace newNamespace) entries;
    in
    concatStringsSep "\n" (if includeHeader then [ markdownHeader ] ++ rows else rows);
}
