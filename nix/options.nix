{ lib }:

let
  inherit (lib) mkEnableOption mkOption types;
in
{
  enable = mkEnableOption "the Hammerspoon Spoons integration";

  manageInit = mkOption {
    type = types.bool;
    default = true;
    description = ''
      Whether to manage ~/.hammerspoon/init.lua. Disable this when an existing
      init.lua should remain authoritative, then require
      "nix-spoons" from that file.
    '';
  };

  extraConfig = mkOption {
    type = types.lines;
    default = "";
    description = ''
      Lua appended to the managed init.lua after the enabled Spoons load.
    '';
  };

  spoons.gearbox.enable = mkOption {
    type = types.bool;
    default = true;
    description = ''
      Whether to install and load Gearbox. Its behavior is configured only by
      Spoons/Gearbox/config.lua.
    '';
  };
}
