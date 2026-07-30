{ lib }:

let
  inherit (lib) mkEnableOption mkOption types;

  nonNegativeNumber = types.addCheck types.number (value: value >= 0);
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

  spoons.gearbox = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install and load Gearbox.";
    };

    menu.timeout = mkOption {
      type = nonNegativeNumber;
      default = 0;
      description = ''
        Seconds before the menu closes. Zero disables timeout and intentionally
        causes Gearbox startup to fail; normal use requires a positive value.
      '';
    };
  };
}
