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
          }
          ''
            mkdir -p "$out"
            cp -R ${../Spoons/Gearbox}/. "$out/"
            chmod u+w "$out/config.lua"
            substituteInPlace "$out/config.lua" \
              --replace-fail "        timeout = 0," "        timeout = $timeout,"
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
