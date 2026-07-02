{
  description = "Independent Hammerspoon Spoons with Home Manager and nix-darwin modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-fuel.url = "github:cig0/nix-fuel?ref=main";
  };

  outputs =
    { self, nix-fuel, ... }:
    {
      /*
        Public option schema for the Home Manager module. Exposing it lets
        downstream flakes reuse the typed option tree under their own namespace
        without depending on internal file paths.
      */
      interfaces.homeManagerOptions = { lib }: import ./nix/options.nix { inherit lib; };

      /*
        Markdown-ready option documentation. Downstream docs can render this
        under any namespace prefix without re-walking the schema.
      */
      interfaces.homeManagerOptionDocs =
        { lib }:
        self._nixOptionsToMd {
          inherit lib;
          options = import ./nix/options.nix { inherit lib; };
          namespace = "programs.hammerspoon-spoons";
        };

      # Reusable helper exposed for internal consumers (devShell, docs).
      _nixOptionsToMd =
        {
          lib,
          options,
          namespace ? "programs.hammerspoon-spoons",
        }:
        nix-fuel.fuelLibs.nixOptionsToMd {
          inherit lib options namespace;
        };

      homeModules = {
        default = self.homeModules.hammerspoon-spoons;
        hammerspoon-spoons = import ./nix/home-manager.nix;
      };

      darwinModules = {
        default = self.darwinModules.hammerspoon-spoons;
        hammerspoon-spoons = import ./nix/darwin.nix;
      };
    };
}
