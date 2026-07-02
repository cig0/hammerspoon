{
  description = "Self-contained devShell that dumps Hammerspoon options to stdout or writes them to the canonical docs file";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          dump-hammerspoon-options = pkgs.writeShellScriptBin "dump-hammerspoon-options" ''
            set -euo pipefail

            FLAKE_REF=""
            TARGET=""
            WRITE=""

            for arg in "$@"; do
              case "$arg" in
                --write)
                  WRITE=1
                  ;;
                *)
                  if [ -z "$FLAKE_REF" ]; then
                    FLAKE_REF="$arg"
                  elif [ -z "$TARGET" ]; then
                    TARGET="$arg"
                  else
                    echo "Unexpected argument: $arg" >&2
                    exit 1
                  fi
                  ;;
              esac
            done

            FLAKE_REF=''${FLAKE_REF:-$HAMMERSPOON_FLAKE_REF}
            TARGET=''${TARGET:-$HAMMERSPOON_DOCS_TARGET}

              if [ -z "$FLAKE_REF" ]; then
                echo "No flake reference available. Run this script from the devShell or pass a flake ref." >&2
                exit 1
              fi
              if [ -z "$TARGET" ]; then
                echo "No target path available. Run this script from the devShell or pass a target path." >&2
                exit 1
              fi

              OUT=$(
                ${pkgs.nix}/bin/nix eval --json --impure --expr "
                  let
                    f = builtins.getFlake \"$FLAKE_REF\";
                    pkgs = import ${toString pkgs.path} { system = \"${system}\"; };
                    docs = f.interfaces.homeManagerOptionDocs { lib = pkgs.lib; };
                  in docs.markdown docs.allEntries
                " | ${pkgs.jq}/bin/jq -r
              )

            if [ -n "$WRITE" ]; then
              mkdir -p "$(dirname "$TARGET")"
              printf '%s\n' "$OUT" > "$TARGET"
              echo "Wrote Hammerspoon options to $TARGET"
            else
              printf '%s\n' "$OUT"
            fi
          '';
        in
        {
          default = pkgs.mkShell {
            name = "nix-docs";
            packages = [
              pkgs.nix
              pkgs.jq
              pkgs.git
              dump-hammerspoon-options
            ];
            shellHook = ''
              CURRENT_ROOT=$(
                ${pkgs.git}/bin/git -C "$PWD" rev-parse --show-toplevel 2>/dev/null \
                  || true
              )
              if [ -n "$CURRENT_ROOT" ] && [ -d "$CURRENT_ROOT/hammerspoon/shells/devShell/nix-docs" ]; then
                REPO_ROOT="$CURRENT_ROOT/hammerspoon"
              elif [ -d "$PWD/hammerspoon/shells/devShell/nix-docs" ]; then
                REPO_ROOT="$PWD/hammerspoon"
              elif [ -n "$CURRENT_ROOT" ] && [ -f "$CURRENT_ROOT/flake.nix" ]; then
                REPO_ROOT="$CURRENT_ROOT"
              else
                REPO_ROOT=${toString ../..}
              fi
              export HAMMERSPOON_FLAKE_REF="path:$REPO_ROOT"
              export HAMMERSPOON_DOCS_TARGET="$REPO_ROOT/assets/docs/ALL-OPTIONS.md"
              echo "dump-hammerspoon-options [flake-ref] [target] [--write]"
            '';
          };
        }
      );
    };
}
