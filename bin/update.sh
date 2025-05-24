#!/bin/bash

AUR_DIR="$HOME/.aur"
UPDATED_PACKAGES=()

# Check if ~/.aur exists
if [ ! -d "$AUR_DIR" ]; then
  echo "Directory $AUR_DIR does not exist."
  exit 1
fi

echo "Updating AUR packages in $AUR_DIR..."

# Loop over each directory in ~/.aur
for pkgdir in "$AUR_DIR"/*; do
  if [ -d "$pkgdir/.git" ]; then
    echo "Checking $pkgdir..."
    cd "$pkgdir" || continue

    # Save current HEAD commit hash
    old_commit=$(git rev-parse HEAD)

    # Pull latest changes
    git pull --quiet

    # Get new HEAD commit hash
    new_commit=$(git rev-parse HEAD)

    # Compare commits to see if updated
    if [ "$old_commit" != "$new_commit" ]; then
      UPDATED_PACKAGES+=("$(basename "$pkgdir")")
      echo "  -> Updated"
    else
      echo "  -> No update"
    fi
  fi
done

# If no packages updated
if [ ${#UPDATED_PACKAGES[@]} -eq 0 ]; then
  echo "No AUR packages were updated."
  exit 0
fi

echo
echo "Updated packages:"
for pkg in "${UPDATED_PACKAGES[@]}"; do
  echo "  - $pkg"
done

echo

# Prompt user for each updated package
for pkg in "${UPDATED_PACKAGES[@]}"; do
  pkg_path="$AUR_DIR/$pkg"
  while true; do
    echo -n "Package '$pkg' was updated. Options: [v]iew PKGBUILD, [u]pgrade, [s]kip? "
    read -r -n1 choice
    echo
    case "$choice" in
      v|V)
        less "$pkg_path/PKGBUILD"
        ;;
      u|U)
        echo "Building and installing $pkg..."
        cd "$pkg_path" || break
        makepkg -si
        break
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
