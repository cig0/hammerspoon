{ lib }:

let
  inherit (lib) mkEnableOption mkOption types;

  unitInterval = types.addCheck types.number (value: value >= 0 && value <= 1);

  nonNegativeNumber = types.addCheck types.number (value: value >= 0);
  positiveNumber = types.addCheck types.number (value: value > 0);
  menuWidth = types.addCheck types.int (value: value >= 200);
  scratchpadWidth = types.addCheck types.int (value: value >= 360);
  scratchpadHeight = types.addCheck types.int (value: value >= 240);
  positiveInteger = types.addCheck types.int (value: value >= 1);
  loupeScale = types.addCheck types.number (value: value >= 1);

  modifiers = types.addCheck (types.listOf (
    types.enum [
      "alt"
      "option"
      "cmd"
      "command"
      "ctrl"
      "control"
      "shift"
    ]
  )) (value: value != [ ]);

  rgba = types.submodule {
    options = {
      red = mkOption {
        type = unitInterval;
      };

      green = mkOption {
        type = unitInterval;
      };

      blue = mkOption {
        type = unitInterval;
      };

      alpha = mkOption {
        type = unitInterval;
        default = 1;
      };
    };
  };

  color =
    defaultAlpha:
    types.submodule {
      options = {
        white = mkOption {
          type = types.nullOr unitInterval;
          default = null;
        };

        red = mkOption {
          type = types.nullOr unitInterval;
          default = null;
        };

        green = mkOption {
          type = types.nullOr unitInterval;
          default = null;
        };

        blue = mkOption {
          type = types.nullOr unitInterval;
          default = null;
        };

        alpha = mkOption {
          type = unitInterval;
          default = defaultAlpha;
        };
      };
    };

  validColor =
    value:
    let
      rgb = [
        value.red
        value.green
        value.blue
      ];
      hasAnyRGB = lib.any (component: component != null) rgb;
      hasAllRGB = lib.all (component: component != null) rgb;
    in
    (value.white != null && !hasAnyRGB) || (value.white == null && hasAllRGB);

  validateColor =
    name: value:
    assert lib.assertMsg (validColor value) ''
      ${name} must define either white or all three RGB components,
      and cannot mix the two color models.
    '';
    value;

  overrideColor = types.submodule {
    options = {
      white = mkOption {
        type = types.nullOr unitInterval;
        default = null;
      };

      red = mkOption {
        type = types.nullOr unitInterval;
        default = null;
      };

      green = mkOption {
        type = types.nullOr unitInterval;
        default = null;
      };

      blue = mkOption {
        type = types.nullOr unitInterval;
        default = null;
      };

      alpha = mkOption {
        type = types.nullOr unitInterval;
        default = null;
      };
    };
  };

  themeOverride = types.submodule (
    { name, ... }:
    let
      optionalColor =
        field:
        mkOption {
          type = types.nullOr overrideColor;
          default = null;
          apply =
            value:
            if value == null then
              null
            else
              validateColor "programs.hammerspoon-spoons.spoons.gearbox.theme.overrides.${name}.${field}" value;
        };
    in
    {
      options = {
        selectionAlpha = mkOption {
          type = types.nullOr unitInterval;
          default = null;
        };

        background = optionalColor "background";
        primary = optionalColor "primary";
        secondary = optionalColor "secondary";
        divider = optionalColor "divider";
        accent = optionalColor "accent";
        accentText = optionalColor "accentText";
      };
    }
  );
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

  spoons = {
    gearbox = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to load the Gearbox launcher.";
      };

      hotkey = {
        modifiers = mkOption {
          type = modifiers;
          default = [
            "alt"
            "cmd"
          ];
          description = "Modifiers used to enter or close Gearbox.";
        };

        key = mkOption {
          type = types.str;
          default = "space";
          description = "Hammerspoon key name used to enter or close Gearbox.";
        };
      };

      menu = {
        timeout = mkOption {
          type = nonNegativeNumber;
          default = 0;
          description = "Seconds before the menu closes; zero disables timeout.";
        };

        position = mkOption {
          type = types.enum [
            "top"
            "center"
            "bottom"
          ];
          default = "top";
          description = "Vertical menu position within the selected screen.";
        };

        screen = mkOption {
          type = types.enum [
            "main"
            "mouse"
          ];
          default = "main";
          description = "Screen on which Gearbox appears.";
        };

        width = mkOption {
          type = menuWidth;
          default = 420;
          description = "Menu width in points.";
        };

        showEmojis = mkOption {
          type = types.bool;
          default = true;
          description = "Whether menu titles include their emoji.";
        };

        highlightGroups = mkOption {
          type = types.bool;
          default = true;
          description = "Whether group keys use the macOS accent color.";
        };
      };

      font = {
        family = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Font family; null uses the macOS system font.";
        };

        size = mkOption {
          type = positiveNumber;
          default = 14;
          description = "Menu item font size.";
        };

        titleSize = mkOption {
          type = positiveNumber;
          default = 20;
          description = "Menu title font size.";
        };

        bodyWeight = mkOption {
          type = types.enum [
            "regular"
            "bold"
          ];
          default = "regular";
        };

        groupWeight = mkOption {
          type = types.enum [
            "regular"
            "bold"
          ];
          default = "bold";
        };

        titleWeight = mkOption {
          type = types.enum [
            "regular"
            "bold"
          ];
          default = "bold";
        };
      };

      loupe = {
        enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Whether keyboard selection magnifies nearby rows.";
        };

        selectedScale = mkOption {
          type = loupeScale;
          default = 1.18;
        };

        adjacentScale = mkOption {
          type = loupeScale;
          default = 1.06;
        };

        duration = mkOption {
          type = nonNegativeNumber;
          default = 0;
          description = "Selection animation duration; zero gives immediate input.";
        };
      };

      theme = {
        name = mkOption {
          type = types.str;
          default = "system";
          description = ''
            Theme ID to select, or "system" to follow the macOS appearance.
          '';
        };

        persistSelection = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether selections made from the Themes menu survive Hammerspoon
            reloads.
          '';
        };

        system = {
          dark = mkOption {
            type = types.str;
            default = "gearbox-dark";
            description = "Theme ID used for the macOS dark appearance.";
          };

          light = mkOption {
            type = types.str;
            default = "gearbox-light";
            description = "Theme ID used for the macOS light appearance.";
          };
        };

        accentSource = mkOption {
          type = types.enum [
            "system"
            "theme"
          ];
          default = "system";
          description = ''
            Whether highlighted controls use the macOS accent or the selected
            theme's accent.
          '';
        };

        fallbackAccent = mkOption {
          type = rgba;
          default = {
            red = 0.04;
            green = 0.48;
            blue = 1;
            alpha = 1;
          };
        };

        systemAccentText = mkOption {
          type = color 1;
          apply = validateColor "programs.hammerspoon-spoons.spoons.gearbox.theme.systemAccentText";
          default = {
            white = 1;
            alpha = 1;
          };
        };

        overrides = mkOption {
          type = types.attrsOf themeOverride;
          default = { };
          description = ''
            Partial semantic color overrides keyed by discovered theme ID.
          '';
        };
      };

      navigation = {
        enabled = mkOption {
          type = types.bool;
          default = true;
        };

        wrap = mkOption {
          type = types.bool;
          default = true;
        };

        activateKey = mkOption {
          type = types.str;
          default = "return";
        };

        cancelKey = mkOption {
          type = types.str;
          default = "escape";
        };

        includeFooter = mkOption {
          type = types.bool;
          default = true;
          description = "Whether arrow navigation can select Back or Exit.";
        };

        resetTimeoutOnInput = mkOption {
          type = types.bool;
          default = true;
          description = "Whether navigation input restarts an enabled timeout.";
        };
      };

      scratchpad = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to expose the editable scratchpad in the Gearbox root menu.";
        };

        menuKey = mkOption {
          type = types.str;
          default = "p";
          description = "Gearbox root-menu key used to open the scratchpad.";
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
  };
}
