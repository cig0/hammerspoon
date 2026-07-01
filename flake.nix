{
  description = "Independent Hammerspoon Spoons with Home Manager and nix-darwin modules";

  outputs = { self, ... }: {
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
