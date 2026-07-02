{
  description = "Independent Hammerspoon Spoons with Home Manager and nix-darwin modules";

  outputs = { self, ... }: {
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
    interfaces.homeManagerOptionDocs = { lib }: import ./nix/option-docs.nix { inherit lib; };

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
