#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

AUR_DIR="${AUR_DIR:-$HOME/Documents/aur}"
UPDATED_PACKAGES=()

# helper: detect default branch for the repo in CWD
get_default_branch() {
  # Try symbolic-ref (fast & reliable for clones)
  if default_branch=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null); then
    echo "${default_branch##refs/remotes/origin/}"
    return 0
  fi

  # Fallback: parse remote show origin
  if default_branch=$(git remote show origin 2>/dev/null | awk -F': ' '/HEAD branch/ {print $2}'); then
    if [[ -n "$default_branch" ]]; then
      echo "$default_branch"
      return 0
    fi
  fi

  # Last fallback
  echo "master"
}

if [[ ! -d "$AUR_DIR" ]]; then
  echo "Directory $AUR_DIR does not exist."
  exit 1
fi

# iterate over each cloned package directory
shopt -s nullglob
for pkgdir in "$AUR_DIR"/*; do
  # ensure it's a git clone
  if [[ -d "$pkgdir/.git" ]]; then
    echo "Checking $(basename "$pkgdir")..."
    pushd "$pkgdir" >/dev/null || continue

    old_commit=$(git rev-parse --verify HEAD 2>/dev/null || echo "")
    default_branch=$(get_default_branch)

    # fetch and reset to the upstream default branch (safe, quiet)
    git fetch --quiet origin --prune
    git reset --hard "origin/$default_branch" --quiet || {
      echo "  -> Could not reset to origin/$default_branch; skipping."
      git status --short --branch | sed -n '1,3p'
      popd >/dev/null
      continue
    }
    git clean -fdx --quiet || true

    new_commit=$(git rev-parse --verify HEAD 2>/dev/null || echo "")
    if [[ "$old_commit" != "$new_commit" ]]; then
      UPDATED_PACKAGES+=("$(basename "$pkgdir")")
      echo "  -> Updated (new commit ${new_commit:0:8})"
    else
      echo "  -> No update"
    fi

    popd >/dev/null
  fi
done
shopt -u nullglob

if [[ ${#UPDATED_PACKAGES[@]} -eq 0 ]]; then
  echo "No AUR packages have an update."
  exit 0
fi

echo
echo "Packages with updates:"
for p in "${UPDATED_PACKAGES[@]}"; do
  echo "  - $p"
done
echo

# interactive loop for each updated package
for pkg in "${UPDATED_PACKAGES[@]}"; do
  pkg_path="$AUR_DIR/$pkg"
  while true; do
    printf "Package '%s' updated. Options: [v]iew PKGBUILD, [u]pgrade, [s]kip? " "$pkg"
    read -r -n1 choice
    echo
    case "$choice" in
      v|V)
        nvim "$pkg_path/PKGBUILD"
        ;;
      u|U)
        echo "Preparing to build $pkg..."

        # don't run makepkg as root
        if [[ "$(id -u)" -eq 0 ]]; then
          echo "Refusing to run makepkg as root. Rerun as normal user."
          break
        fi

        # check for pkg/ permission issues (common if previously run as root)
        if [[ -d "$pkg_path/pkg" ]] && [[ "$(stat -c %u "$pkg_path/pkg")" -eq 0 ]]; then
          echo "Warning: $pkg_path/pkg is owned by root. This will break makepkg."
          read -rp "Remove it (r), chown to $USER (c), or abort build (a)? [r/c/a] " fixchoice
          case "$fixchoice" in
            r|R) rm -rf "$pkg_path/pkg" ;;
            c|C) sudo chown -R "$USER:$USER" "$pkg_path/pkg" ;;
            *) echo "Aborting build for $pkg."; break ;;
          esac
        fi

        pushd "$pkg_path" >/dev/null || break

        # save commit to allow rollback on build failure
        saved_commit=$(git rev-parse --verify HEAD)

        # run build; minimal flags
        if makepkg -si --noconfirm --needed; then
          echo "OK: $pkg installed."
          popd >/dev/null
          break
        else
          echo "Build failed for $pkg — rolling back to previous commit."
          # try to rollback; if rollback fails, notify and leave dir as-is
          if git rev-parse --verify "$saved_commit" >/dev/null 2>&1; then
            git reset --hard "$saved_commit" --quiet || true
            git clean -fdx --quiet || true
            echo "Rolled back to ${saved_commit:0:8}."
          else
            echo "Saved commit not available; manual intervention required."
          fi
          popd >/dev/null
          # open package page for diagnostics
          if command -v xdg-open &>/dev/null; then
            xdg-open "https://aur.archlinux.org/packages/$pkg" &>/dev/null || true
          else
            echo "Inspect: https://aur.archlinux.org/packages/$pkg"
          fi
          break
        fi
        ;;
      s|S)
        echo "Skipping $pkg."
        break
        ;;
      *)
        echo "Invalid option. Please enter v, u, or s."
        ;;
    esac
  done
done

exit 0
