{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.hammerspoon-spoons;
  renderLua = import ./render-lua.nix { inherit lib; };
  gearboxSettings = builtins.removeAttrs cfg.gearbox [ "enable" ];
  activateKey = lib.toLower cfg.gearbox.navigation.activateKey;
  cancelKey = lib.toLower cfg.gearbox.navigation.cancelKey;

  spoonLoader = ''
    -- Nix-generated loader for enabled Hammerspoon Spoons.
    -- programs.hammerspoon-spoons.* → this file → Spoons/<name>.start()
    -- Loaded by ~/.hammerspoon/init.lua through require("nix-spoons").
    ${lib.optionalString cfg.gearbox.enable ''
      require("Spoons.Gearbox").start(${renderLua gearboxSettings})
    ''}
  '';
in
{
  options.programs.hammerspoon-spoons = import ./options.nix { inherit lib pkgs; };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.gearbox.loupe.adjacentScale <= cfg.gearbox.loupe.selectedScale;
        message = ''
          programs.hammerspoon-spoons.gearbox.loupe.adjacentScale
          cannot exceed selectedScale.
        '';
      }
      {
        assertion = !cfg.gearbox.navigation.enabled || activateKey != cancelKey;
        message = ''
          Gearbox navigation activateKey and cancelKey must differ.
        '';
      }
      {
        assertion =
          !cfg.gearbox.navigation.enabled
          || !builtins.elem activateKey [
            "up"
            "down"
          ];
        message = ''
          Gearbox navigation activateKey cannot be up or down.
        '';
      }
    ];

    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file = lib.mkMerge [
      {
        ".hammerspoon/nix-spoons.lua".text = spoonLoader;
      }

      (lib.mkIf cfg.gearbox.enable {
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
  };
}
