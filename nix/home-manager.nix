{
  config,
  lib,
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
      renderLua = import ./render-lua.nix { inherit lib; };
      gearboxSettings = builtins.removeAttrs gb [ "enable" ];
      activateKey = lib.toLower gb.navigation.activateKey;
      cancelKey = lib.toLower gb.navigation.cancelKey;

      spoonLoader = ''
        -- Nix-generated loader for enabled Hammerspoon Spoons.
        -- programs.hammerspoon-spoons.* → this file → Spoons/<name>.start()
        -- Loaded by ~/.hammerspoon/init.lua through require("nix-spoons").
        ${lib.optionalString gb.enable ''
          require("Spoons.Gearbox").start(${renderLua gearboxSettings})
        ''}
      '';
    in
    {
      assertions = [
        {
          assertion = gb.loupe.adjacentScale <= gb.loupe.selectedScale;
          message = ''
            programs.hammerspoon-spoons.spoons.gearbox.loupe.adjacentScale
            cannot exceed selectedScale.
          '';
        }
        {
          assertion = !gb.navigation.enabled || activateKey != cancelKey;
          message = ''
            Gearbox navigation activateKey and cancelKey must differ.
          '';
        }
        {
          assertion =
            !gb.navigation.enabled
            || !builtins.elem activateKey [
              "up"
              "down"
            ];
          message = ''
            Gearbox navigation activateKey cannot be up or down.
          '';
        }
      ];

      home.file = lib.mkMerge [
        {
          ".hammerspoon/nix-spoons.lua".text = spoonLoader;
        }

        (lib.mkIf gb.enable {
          ".hammerspoon/Spoons/Gearbox".source = ../Spoons/Gearbox;
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
