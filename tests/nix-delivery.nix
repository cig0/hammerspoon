{ pkgs, self }:

let
  # Supply only the Home Manager surface this module uses. The generated
  # activation shell is exercised below, without changing a real home.
  lib = pkgs.lib.extend (
    final: prev: {
      hm.dag.entryAfter = after: data: { inherit after data; };
    }
  );

  activationFor =
    {
      gearboxEnable ? true,
      manageInit ? true,
      customize ? true,
    }:
    let
      evaluated = lib.evalModules {
        specialArgs = { inherit pkgs self; };
        modules = [
          self.homeModules.default
          (
            { lib, ... }:
            {
              options.home.homeDirectory = lib.mkOption { type = lib.types.str; };
              options.home.activation = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
              };

              config.home.homeDirectory = "$TEST_HOME";
              config.programs.hammerspoon-spoons = {
                enable = true;
                inherit manageInit;
                extraConfig = "-- delivery check";
                spoons.gearbox = {
                  enable = gearboxEnable;
                }
                // lib.optionalAttrs customize {
                  menu = {
                    timeout = 5;
                    position = "bottom";
                  };
                  scratchpad = {
                    enable = false;
                    fontSize = 18;
                    width = 800;
                    height = 600;
                    maxCharacters = 3000;
                    persistContent = false;
                    showInstructions = false;
                  };
                };
              };
            }
          )
        ];
      };
    in
    pkgs.writeText "hammerspoon-activation" evaluated.config.home.activation.hammerspoonSpoons.data;

  enabled = activationFor { };
  disabled = activationFor {
    gearboxEnable = false;
    manageInit = false;
  };
  defaults = activationFor { customize = false; };
  shippedGearbox = self.outPath + "/Spoons/Gearbox";
in
pkgs.runCommand "hammerspoon-delivery-check" { } ''
  set -eu
  export TEST_HOME="$TMPDIR/home"
  mkdir -p "$TEST_HOME"

  # Home Manager's run wrapper is only needed to invoke the commands here.
  run() { "$@"; }
  activateEnabled() { source ${enabled}; }
  activateDisabled() { source ${disabled}; }
  activateDefaults() { source ${defaults}; }

  activateEnabled
  root="$TEST_HOME/.hammerspoon"
  config="$root/Spoons/Gearbox/config.lua"
  test -f "$root/nix-spoons.lua"
  test -f "$root/init.lua"
  test -f "$config"
  test -f "$root/Spoons/Gearbox/lib/RetroUI/package.json"
  test ! -L "$root/Spoons/Gearbox"
  test -w "$config"
  grep -Fq 'require("Spoons.Gearbox").start()' "$root/nix-spoons.lua"
  grep -Fq 'require("nix-spoons")' "$root/init.lua"
  grep -Fq -- '-- delivery check' "$root/init.lua"

  # All nine anchors must be replaced in the deployed tree. A missing source
  # anchor also fails earlier in the configuredGearbox build.
  grep -Fqx '        timeout = 5, -- Zero disables timeout and intentionally aborts startup.' "$config"
  grep -Fqx '        position = "bottom", -- "top", "center", "bottom"' "$config"
  grep -Fqx '        enable = false,' "$config"
  grep -Fqx '        fontSize = 18,' "$config"
  grep -Fqx '        width = 800,' "$config"
  grep -Fqx '        height = 600,' "$config"
  grep -Fqx '        maxCharacters = 3000,' "$config"
  grep -Fqx '        persistContent = false,' "$config"
  grep -Fqx '        showInstructions = false' "$config"

  # Re-activation of unchanged files should replace them without backups.
  activateEnabled
  test ! -e "$config.hm-bak"
  test ! -e "$root/nix-spoons.lua.hm-bak"

  # Changed files and trees are preserved, including an existing backup.
  printf '\n-- local edit\n' >> "$config"
  printf '\n-- local edit\n' >> "$root/nix-spoons.lua"
  activateEnabled
  grep -Fq -- '-- local edit' "$root/Spoons/Gearbox.hm-bak/config.lua"
  grep -Fq -- '-- local edit' "$root/nix-spoons.lua.hm-bak"
  printf '\n-- second edit\n' >> "$config"
  activateEnabled
  grep -Fq -- '-- second edit' "$root/Spoons/Gearbox.hm-bak-1/config.lua"

  # A legacy Home Manager symlink is replaced with a regular copy.
  rm "$root/nix-spoons.lua"
  ln -s /nonexistent/nix-spoons.lua "$root/nix-spoons.lua"
  activateEnabled
  test -f "$root/nix-spoons.lua"
  test ! -L "$root/nix-spoons.lua"

  # Disabling Gearbox compares against the unsubstituted shipped source.
  # An enabled, substituted tree is therefore preserved on removal.
  activateDisabled
  test ! -e "$root/Spoons/Gearbox"
  test -f "$root/Spoons/Gearbox.hm-bak-2/config.lua"
  test -f "$root/init.lua" # manageInit=false leaves an external entrypoint alone.
  ! grep -Fq 'require("Spoons.Gearbox").start()' "$root/nix-spoons.lua"

  # A tree identical to the shipped source needs no backup when disabled.
  cp -R ${shippedGearbox} "$root/Spoons/Gearbox"
  chmod -R u+w "$root/Spoons/Gearbox"
  activateDisabled
  test ! -e "$root/Spoons/Gearbox"
  test ! -e "$root/Spoons/Gearbox.hm-bak-3"

  # A changed source tree, and then a symlink, use the same removal decision.
  cp -R ${shippedGearbox} "$root/Spoons/Gearbox"
  chmod -R u+w "$root/Spoons/Gearbox"
  printf '\n-- disabled edit\n' >> "$root/Spoons/Gearbox/config.lua"
  activateDisabled
  grep -Fq -- '-- disabled edit' "$root/Spoons/Gearbox.hm-bak-3/config.lua"
  ln -s ${shippedGearbox} "$root/Spoons/Gearbox"
  activateDisabled
  test ! -e "$root/Spoons/Gearbox"
  test ! -L "$root/Spoons/Gearbox"

  # The schema defaults and substitution anchors yield the shipped config.
  export TEST_HOME="$TMPDIR/default-home"
  mkdir -p "$TEST_HOME"
  activateDefaults
  diff -r ${shippedGearbox} "$TEST_HOME/.hammerspoon/Spoons/Gearbox"

  touch "$out"
''
