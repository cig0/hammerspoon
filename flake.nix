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

      # The module is reusable on any system; these systems build its delivery
      # regression check without exporting runtime packages.
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      perSystem =
        { system, ... }:
        let
          pkgs = import inputs.nix-batteries.inputs.nixpkgs { inherit system; };
        in
        {
          checks.hammerspoon-delivery = import ./tests/nix-delivery.nix {
            inherit pkgs;
            self = inputs.self;
          };
        };
    };
}
