#!/usr/bin/env bash

AUR_DIR="$HOME/Templates/aur"
UPDATED_PACKAGES=()

if [ ! -d "$AUR_DIR" ]; then
    echo "Directory $AUR_DIR does not exist."
    exit 1
fi

for pkgdir in "$AUR_DIR"/*; do
    if [ -d "$pkgdir/.git" ]; then
        echo "Checking $pkgdir..."
        cd "$pkgdir" || continue

        # Save current HEAD commit hash
        old_commit=$(git rev-parse HEAD)

        # Fetch and hard reset to latest master
        git fetch --quiet origin
        git reset --hard origin/master --quiet
        git clean -fdx --quiet

        # Get new HEAD commit hash
        new_commit=$(git rev-parse HEAD)

        # Compare commits to detect update
        if [ "$old_commit" != "$new_commit" ]; then
            UPDATED_PACKAGES+=("$(basename "$pkgdir")")
            echo "  -> Updated"
        else
            echo "  -> No update"
        fi
    fi
done

if [ ${#UPDATED_PACKAGES[@]} -eq 0 ]; then
    echo "No AUR packages have an update."
    exit 0
fi

echo
echo "Packages need to be updated:"
for pkg in "${UPDATED_PACKAGES[@]}"; do
    echo "  - $pkg"
done

echo

for pkg in "${UPDATED_PACKAGES[@]}"; do
    pkg_path="$AUR_DIR/$pkg"
    while true; do
        echo -n "Package: '$pkg' has an update. Options: [v]iew PKGBUILD, [u]pgrade, [s]kip? "
        read -r -n1 choice
        echo
        case "$choice" in
        v | V)
            nvim "$pkg_path/PKGBUILD"
            ;;
        u | U)
            echo "Building and installing $pkg..."
            cd "$pkg_path" || break
            makepkg -si --clean --cleanbuild --noconfirm --needed
            break
            ;;
        s | S)
            echo "Skipping $pkg."
            break
            ;;
        *)
            echo "Invalid option. Please enter v, u, or s."
            ;;
        esac
    done
done
