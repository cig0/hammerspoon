{
  config,
  inputs,
  self,
  ...
}:

let
  # Share one option contract between the Home Manager module and the docs interface.
  optionsFor =
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
            leaves Gearbox stopped while showing its configuration dialog; normal
            use requires a positive value.
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
    };

  # Keep the schema, staging, and activation in one module while Gearbox is the
  # only Spoon with bespoke delivery. Split by responsibility if a second Spoon
  # needs its own staging path or deployment gains a third distinct case.
  homeModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.programs.hammerspoon-spoons;
    in
    {
      options.programs.hammerspoon-spoons = optionsFor { inherit lib; };

      config = lib.mkIf cfg.enable (
        let
          gb = cfg.spoons.gearbox;

          gearboxSource = self.outPath + "/Spoons/Gearbox";

          /*
            The shipped config.lua literals, option defaults above, and
            substituteInPlace anchors below intentionally agree. Nix owns these
            deployment-time values; --replace-fail makes source drift a build
            failure instead of silently shipping an unconfigured Spoon.
            Stage in the store first, then deploy a writable copy on activation.
          */
          configuredGearbox =
            pkgs.runCommand "gearbox-configured"
              {
                timeout = builtins.toJSON gb.menu.timeout;
                menuPosition = builtins.toJSON gb.menu.position;
                scratchpadEnable = builtins.toJSON gb.scratchpad.enable;
                scratchpadFontSize = builtins.toJSON gb.scratchpad.fontSize;
                scratchpadWidth = builtins.toJSON gb.scratchpad.width;
                scratchpadHeight = builtins.toJSON gb.scratchpad.height;
                scratchpadMaxCharacters = builtins.toJSON gb.scratchpad.maxCharacters;
                scratchpadPersistContent = builtins.toJSON gb.scratchpad.persistContent;
                scratchpadShowInstructions = builtins.toJSON gb.scratchpad.showInstructions;
              }
              ''
                mkdir -p "$out"
                cp -R "${gearboxSource}/." "$out/"
                chmod u+w "$out/config.lua"
                substituteInPlace "$out/config.lua" \
                  --replace-fail "        timeout = 0," "        timeout = $timeout," \
                  --replace-fail '        position = "top",' "        position = $menuPosition," \
                  --replace-fail "        enable = true," "        enable = $scratchpadEnable," \
                  --replace-fail "        fontSize = 14," "        fontSize = $scratchpadFontSize," \
                  --replace-fail "        width = 720," "        width = $scratchpadWidth," \
                  --replace-fail "        height = 480," "        height = $scratchpadHeight," \
                  --replace-fail "        maxCharacters = 4096," "        maxCharacters = $scratchpadMaxCharacters," \
                  --replace-fail "        persistContent = true," "        persistContent = $scratchpadPersistContent," \
                  --replace-fail "        showInstructions = true" "        showInstructions = $scratchpadShowInstructions"
              '';

          # Generated entrypoint: loading stays independent of manageInit so an
          # externally owned init.lua can require("nix-spoons") itself.
          spoonLoader = ''
            -- Nix-generated loader for enabled Hammerspoon Spoons.
            -- programs.hammerspoon-spoons.* → this file → Spoons/<name>.start()
            -- Loaded by ~/.hammerspoon/init.lua through require("nix-spoons").
            ${lib.optionalString gb.enable ''
              require("Spoons.Gearbox").start()
            ''}
          '';
          managedInit = ''
            -- Home Manager-managed Hammerspoon entrypoint.
            -- programs.hammerspoon-spoons.* → nix-spoons.lua → enabled Spoons.
            require("nix-spoons")

            ${cfg.extraConfig}
          '';

          # This layout is the complete set of enabled files activation copies.
          # Keep it named so staging and target paths are easy to compare.
          managedFiles = pkgs.runCommand "hammerspoon-managed-files" { } ''
            mkdir -p "$out"
            cp ${pkgs.writeText "nix-spoons.lua" spoonLoader} "$out/nix-spoons.lua"
            ${lib.optionalString cfg.manageInit ''
              cp ${pkgs.writeText "init.lua" managedInit} "$out/init.lua"
            ''}
            ${lib.optionalString gb.enable ''
              mkdir -p "$out/Spoons"
              cp -R ${configuredGearbox} "$out/Spoons/Gearbox"
            ''}
          '';
        in
        {
          /*
            Every managed file is deployed as a regular, user-owned, user-writable
            copy so the configuration can be edited and reloaded live without
            rebuilding the flake. Each Home Manager activation re-asserts the
            flake-shipped content; keeping a local edit means porting it back to
            this repository first. An edited target is moved to <target>.hm-bak
            before the fresh copy lands, without overwriting prior backups.
          */
          home.activation.hammerspoonSpoons = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            hammerspoonDir="${config.home.homeDirectory}/.hammerspoon"

            # Preserve every changed copy, including earlier backups. A target
            # may differ because of a local edit or a new flake revision.
            preserveChangedCopy() {
              local dst="$1"
              local backup="$dst.hm-bak"
              local suffix=1

              while [ -e "$backup" ] || [ -L "$backup" ]; do
                backup="$dst.hm-bak-$suffix"
                suffix=$((suffix + 1))
              done

              run mv "$dst" "$backup"
              run echo "hammerspoon-spoons: changed copy moved to $backup"
            }

            # removeExistingCopy <baseline> <dst> removes an identical target
            # or preserves a changed one. Symlinks are always removed; comparing
            # them with diff would follow a Home Manager store link.
            removeExistingCopy() {
              local baseline="$1"
              local dst="$2"

              if [ -L "$dst" ]; then
                run rm -f "$dst"
              elif [ -e "$dst" ]; then
                if diff -r "$baseline" "$dst" > /dev/null 2>&1; then
                  run rm -rf "$dst"
                else
                  preserveChangedCopy "$dst"
                fi
              fi
            }

            # installMutableCopy <src> <dst> replaces dst with a writable copy.
            installMutableCopy() {
              local src="$1"
              local dst="$2"

              removeExistingCopy "$src" "$dst"
              run mkdir -p "$(dirname "$dst")"
              run cp -R "$src" "$dst"
              run chmod -R u+w "$dst"
            }

            installMutableCopy "${managedFiles}/nix-spoons.lua" "$hammerspoonDir/nix-spoons.lua"
            ${lib.optionalString cfg.manageInit ''
              installMutableCopy "${managedFiles}/init.lua" "$hammerspoonDir/init.lua"
            ''}
            ${lib.optionalString gb.enable ''
              installMutableCopy "${managedFiles}/Spoons/Gearbox" "$hammerspoonDir/Spoons/Gearbox"
            ''}
            ${lib.optionalString (!gb.enable) ''
              # Compare disabled Gearbox against the shipped source. The enabled
              # copy may contain Nix substitutions, so it must be backed up.
              gearboxDir="$hammerspoonDir/Spoons/Gearbox"
              removeExistingCopy "${gearboxSource}" "$gearboxDir"
            ''}
          '';
        }
      );
    };
in
{
  flake.modules.homeManager.hammerspoon-spoons = homeModule;

  # Keep the established Home Manager import paths for consumers.
  flake.homeModules = {
    default = config.flake.modules.homeManager.hammerspoon-spoons;
    hammerspoon-spoons = config.flake.modules.homeManager.hammerspoon-spoons;
  };

  flake.interfaces.homeManagerOptions = optionsFor;
  flake.interfaces.homeManagerOptionDocs =
    { lib }:
    inputs.nix-batteries.batteriesLib.nixOptionsToMd {
      inherit lib;
      options = optionsFor { inherit lib; };
      namespace = "programs.hammerspoon-spoons";
    };
}
