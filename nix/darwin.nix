{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.hammerspoon-spoons;
in
{
  options.programs.hammerspoon-spoons.user = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "jane";
    description = ''
      Home Manager user that owns the Hammerspoon configuration.
      This nix-darwin adapter requires Home Manager's nix-darwin module.
    '';
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.user != null;
            message = ''
              programs.hammerspoon-spoons.user must name the Home Manager user
              when the nix-darwin adapter is enabled.
            '';
          }
        ];
      }

      (lib.mkIf (cfg.user != null) {
        home-manager.users.${cfg.user} = {
          imports = [ ./home-manager.nix ];

          programs.hammerspoon-spoons = builtins.removeAttrs cfg [ "user" ];
        };
      })
    ]
  );
}
