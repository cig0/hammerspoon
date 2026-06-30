{
  description = "Independent Hammerspoon gadgets with Home Manager and nix-darwin modules";

  outputs = { self, ... }: {
    homeModules = {
      default = self.homeModules.hammerspoon-gadgets;
      hammerspoon-gadgets = import ./nix/home-manager.nix;
    };

    darwinModules = {
      default = self.darwinModules.hammerspoon-gadgets;
      hammerspoon-gadgets = import ./nix/darwin.nix;
    };
  };
}
