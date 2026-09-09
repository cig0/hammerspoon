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

      /*
        Store-side staging copy with the typed options substituted into
        config.lua; activation deploys it to ~/.hammerspoon as plain
        user-writable files.
      */
      configuredGearbox =
        pkgs.runCommand "gearbox-configured"
          {
            timeout = builtins.toJSON gb.menu.timeout;
            menuPosition = builtins.toJSON gb.menu.position;
            scratchpadEnable = builtins.toJSON gb.scratchpad.enable;
            scratchpadFontSize = builtins.toJSON gb.scratchpad.fontSize;
            scratchpadWidth = builtins.toJSON gb.scratchpad.width;
            scratchpadHeight = builtins.toJSON gb.scratchpad.height;
            scratchpadMaxCharacters = builtins.toJSON gb.scratchpad.maxCharacters;
            scratchpadPersistContent = builtins.toJSON gb.scratchpad.persistContent;
            scratchpadShowInstructions = builtins.toJSON gb.scratchpad.showInstructions;
          }
          ''
            mkdir -p "$out"
            cp -R ${../Spoons/Gearbox}/. "$out/"
            chmod u+w "$out/config.lua"
            substituteInPlace "$out/config.lua" \
              --replace-fail "        timeout = 0," "        timeout = $timeout," \
              --replace-fail '        position = "top",' "        position = $menuPosition," \
              --replace-fail "        enable = true," "        enable = $scratchpadEnable," \
              --replace-fail "        fontSize = 14," "        fontSize = $scratchpadFontSize," \
              --replace-fail "        width = 720," "        width = $scratchpadWidth," \
              --replace-fail "        height = 480," "        height = $scratchpadHeight," \
              --replace-fail "        maxCharacters = 4096," "        maxCharacters = $scratchpadMaxCharacters," \
              --replace-fail "        persistContent = true," "        persistContent = $scratchpadPersistContent," \
              --replace-fail "        showInstructions = true" "        showInstructions = $scratchpadShowInstructions"
          '';

      spoonLoader = ''
        -- Nix-generated loader for enabled Hammerspoon Spoons.
        -- programs.hammerspoon-spoons.* → this file → Spoons/<name>.start()
        -- Loaded by ~/.hammerspoon/init.lua through require("nix-spoons").
        ${lib.optionalString gb.enable ''
          require("Spoons.Gearbox").start()
        ''}
      '';
      managedInit = ''
        -- Home Manager-managed Hammerspoon entrypoint.
        -- programs.hammerspoon-spoons.* → nix-spoons.lua → enabled Spoons.
        require("nix-spoons")

        ${cfg.extraConfig}
      '';

      managedFiles = pkgs.runCommand "hammerspoon-managed-files" { } ''
        mkdir -p "$out"
        cp ${pkgs.writeText "nix-spoons.lua" spoonLoader} "$out/nix-spoons.lua"
        ${lib.optionalString cfg.manageInit ''
          cp ${pkgs.writeText "init.lua" managedInit} "$out/init.lua"
        ''}
        ${lib.optionalString gb.enable ''
          mkdir -p "$out/Spoons"
          cp -R ${configuredGearbox} "$out/Spoons/Gearbox"
        ''}
      '';
    in
    {
      /*
        Every managed file is deployed as a regular, user-owned, user-writable
        copy so the configuration can be edited and reloaded live without
        rebuilding the flake. Each Home Manager activation re-asserts the
        flake-shipped content; keeping a local edit means porting it back to
        this repository first. An edited target is moved to <target>.hm-bak
        before the fresh copy lands.
      */
      home.activation.hammerspoonSpoons = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        hammerspoonDir="${config.home.homeDirectory}/.hammerspoon"

        # installMutableCopy <src> <dst> replaces dst with a writable copy of
        # src. Store symlinks and untouched copies are dropped silently; an
        # edited copy is preserved as dst.hm-bak.
        installMutableCopy() {
          local src="$1"
          local dst="$2"

          if [ -L "$dst" ]; then
            run rm -f "$dst"
          elif [ -e "$dst" ]; then
            if diff -r "$src" "$dst" > /dev/null 2>&1; then
              run rm -rf "$dst"
            else
              run rm -rf "$dst.hm-bak"
              run mv "$dst" "$dst.hm-bak"
              run echo "hammerspoon-spoons: edited copy moved to $dst.hm-bak"
            fi
          fi

          run mkdir -p "$(dirname "$dst")"
          run cp -R "$src" "$dst"
          run chmod -R u+w "$dst"
        }

        installMutableCopy "${managedFiles}/nix-spoons.lua" "$hammerspoonDir/nix-spoons.lua"
        ${lib.optionalString cfg.manageInit ''
          installMutableCopy "${managedFiles}/init.lua" "$hammerspoonDir/init.lua"
        ''}
        ${lib.optionalString gb.enable ''
          installMutableCopy "${managedFiles}/Spoons/Gearbox" "$hammerspoonDir/Spoons/Gearbox"
        ''}
        ${lib.optionalString (!gb.enable) ''
          # Gearbox is disabled: drop the deployed copy, preserving local edits.
          gearboxDir="$hammerspoonDir/Spoons/Gearbox"
          if [ -L "$gearboxDir" ]; then
            run rm -f "$gearboxDir"
          elif [ -e "$gearboxDir" ]; then
            if diff -r "${../Spoons/Gearbox}" "$gearboxDir" > /dev/null 2>&1; then
              run rm -rf "$gearboxDir"
            else
              run rm -rf "$gearboxDir.hm-bak"
              run mv "$gearboxDir" "$gearboxDir.hm-bak"
              run echo "hammerspoon-spoons: edited copy moved to $gearboxDir.hm-bak"
            fi
          fi
        ''}
      '';
    }
  );
}
