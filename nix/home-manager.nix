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
  options.programs.hammerspoon-spoons = import ./options.nix { inherit lib; };

  config = lib.mkIf cfg.enable (
    let
      gb = cfg.spoons.gearbox;
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
            cp -R ${../Spoons/Gearbox}/. "$out/"
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

      spoonLoader = ''
        -- Nix-generated loader for enabled Hammerspoon Spoons.
        -- programs.hammerspoon-spoons.* → this file → Spoons/<name>.start()
        -- Loaded by ~/.hammerspoon/init.lua through require("nix-spoons").
        ${lib.optionalString gb.enable ''
          require("Spoons.Gearbox").start()
        ''}
      '';
    in
    {
      home.file = lib.mkMerge [
        {
          ".hammerspoon/nix-spoons.lua".text = spoonLoader;
        }

        (lib.mkIf gb.enable {
          ".hammerspoon/Spoons/Gearbox".source = configuredGearbox;
        })

        (lib.mkIf cfg.manageInit {
          ".hammerspoon/init.lua".text = ''
            -- Home Manager-managed Hammerspoon entrypoint.
            -- programs.hammerspoon-spoons.* → nix-spoons.lua → enabled Spoons.
            require("nix-spoons")

            ${cfg.extraConfig}
          '';
        })
      ];
    }
  );
}
