{
  description = "Independent Hammerspoon Spoons with an optional Home Manager module";

  inputs = {
    nix-batteries.url = "github:cig0/nix-batteries?ref=main";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        flake-parts.flakeModules.modules
        ./modules/hammerspoon-spoons.nix
      ];

      # This flake exports a reusable module, not per-system packages.
      systems = [ ];
    };
}
