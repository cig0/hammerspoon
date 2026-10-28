# Sourced by Home Manager activation. GNU coreutils/diffutils are on its PATH.
# Mirrored in hammerspoon/nix/mutable-copy.sh; keep the behavioral tests in sync.
installMutableCopy() (
  set -eu
  src=$1
  dst=$2
  mode=${3:-u+w}
  if [[ -n ${DRY_RUN+x} || -n ${DRY_RUN_CMD:-} ]]; then
    printf 'Would install writable copy at %s\n' "$dst"
    exit 0
  fi

  # Prepare the complete replacement before touching the current target.
  mkdir -p -- "$(dirname "$dst")"
  stage=$(mktemp -d "$dst.hm-stage.XXXXXX")
  trap 'rm -rf -- "$stage"' EXIT
  cp -RL -- "$src" "$stage/content"
  chmod -R "$mode" -- "$stage/content"

  if [[ -e $dst && ! -L $dst ]]; then
    difference=0
    diff -r -- "$stage/content" "$dst" >/dev/null || difference=$?
    case $difference in
      0) chmod -R "$mode" -- "$dst"; exit 0 ;;
      1) ;;
      *) printf 'Cannot compare %s; leaving it unchanged.\n' "$dst" >&2; exit "$difference" ;;
    esac
  fi

  if [[ -e $dst || -L $dst ]]; then
    # Unique, private backups survive repeated switches and rollback generations.
    backup=$(mktemp -d "$dst.hm-bak.XXXXXX")
    if [[ -d $dst && ! -L $dst ]]; then
      mv -T -- "$dst" "$backup/original"
      if ! mv -T -- "$stage/content" "$dst"; then
        if ! mv -T -- "$backup/original" "$dst"; then
          printf 'Restore failed; recover %s/original to %s.\n' "$backup" "$dst" >&2
        fi
        exit 1
      fi
    else
      cp -RPp -- "$dst" "$backup/original"
      # A concurrent editor must not lose changes made while taking the backup.
      if [[ ! -L $dst ]] && ! cmp -s -- "$dst" "$backup/original"; then
        printf 'Config changed while backing up %s; leaving it unchanged.\n' "$dst" >&2
        exit 1
      fi
      mv -fT -- "$stage/content" "$dst"
    fi
    printf 'Previous copy preserved at %s/original\n' "$backup"
  else
    mv -T -- "$stage/content" "$dst"
  fi
)

# Disabled assets are retained for recovery, including locally edited trees.
preserveMutableCopy() (
  set -eu
  dst=$1
  if [[ ! -e $dst && ! -L $dst ]]; then exit 0; fi
  if [[ -n ${DRY_RUN+x} || -n ${DRY_RUN_CMD:-} ]]; then
    printf 'Would preserve disabled asset at %s\n' "$dst"
    exit 0
  fi
  backup=$(mktemp -d "$dst.hm-bak.XXXXXX")
  mv -T -- "$dst" "$backup/original"
  printf 'Disabled asset preserved at %s/original\n' "$backup"
)
