{ lib }:

let
  inherit (lib) mkEnableOption mkOption types;

  nonNegativeNumber = types.addCheck types.number (value: value >= 0);
  positiveNumber = types.addCheck types.number (value: value > 0);
  scratchpadWidth = types.addCheck types.int (value: value >= 360);
  scratchpadHeight = types.addCheck types.int (value: value >= 240);
  positiveInteger = types.addCheck types.int (value: value >= 1);
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

    menu.position = mkOption {
      type = types.enum [
        "top"
        "bottom"
      ];
      default = "top";
      description = ''
        Shared vertical placement for the Gearbox menu and Scratchpad. Bottom
        mirrors the top offset from the opposite screen edge.
      '';
    };

    scratchpad = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to expose the editable scratchpad in the Gearbox root menu.";
      };

      fontSize = mkOption {
        type = positiveNumber;
        default = 14;
        description = "Scratchpad editor font size in pixels.";
      };

      width = mkOption {
        type = scratchpadWidth;
        default = 720;
        description = "Scratchpad width in points.";
      };

      height = mkOption {
        type = scratchpadHeight;
        default = 480;
        description = "Scratchpad height in points.";
      };

      maxCharacters = mkOption {
        type = positiveInteger;
        default = 4096;
        description = ''
          Maximum editable scratchpad capacity in characters. Existing saved
          content above the limit is preserved and must be reduced before
          more text can be added.
        '';
      };

      persistContent = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether scratchpad content survives Hammerspoon reloads through
          local, unencrypted hs.settings storage.
        '';
      };

      showInstructions = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to show the non-editable keyboard reference footer.";
      };
    };
  };
}
