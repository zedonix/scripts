#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<EOF
Usage: $0 <package-name|aur-git-url>
Example: $0 poweralertd
         $0 https://aur.archlinux.org/poweralertd.git
EOF
  exit 1
}

if [[ ${1:-} == "" ]]; then
  usage
fi

input="$1"
aur_dir="$HOME/Documents/aur"
mkdir -p "$aur_dir"
cd "$aur_dir"

# Detect URL or package name (support .git and no .git variants)
if [[ "$input" =~ ^https?:// ]]; then
  # try to extract package name from the URL
  pkg="$(basename "${input%/.git}")"
  url="$input"
else
  pkg="$input"
  url="https://aur.archlinux.org/${pkg}.git"
fi

echo "Target: $pkg"
echo "Cloning from: $url"

# If directory already exists, offer to update or reuse
if [[ -d "$pkg" ]]; then
  echo "Directory '$pkg' already exists."
  read -rp "Pull latest changes (p), remove and reclone (r), or use existing (any other key)? " choice
  case "$choice" in
    [Pp]*) (cd "$pkg" && git pull --ff-only || { echo "Pull failed"; exit 1; }) ;;
    [Rr]*) rm -rf "$pkg" && git clone --depth 1 "$url" "$pkg" ;;
    *) echo "Using existing directory." ;;
  esac
else
  git clone --depth 1 "$url" "$pkg"
fi

cd "$pkg"

# Ensure PKGBUILD exists
if [[ ! -f PKGBUILD ]]; then
  echo "Error: PKGBUILD not found in $pkg. Removing directory."
  cd ..
  rm -rf "$pkg"
  exit 1
fi


nvim PKGBUILD

# Prompt (default yes). Accept y, Y, yes, YES etc.
read -rp "Build and install '$pkg'? [Y/n] " reply
reply=${reply:-Y}
if [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
  # DON'T run makepkg as root; bail if root
  if [[ $(id -u) -eq 0 ]]; then
    echo "Refusing to run makepkg as root. Rerun as normal user."
    exit 1
  fi

  # Use conservative makepkg flags
  if makepkg -si --noconfirm --needed; then
    echo "OK: $pkg installed."
  else
    echo "Build failed. Opening package page on AUR for diagnostics..."
    if command -v xdg-open &>/dev/null; then
      xdg-open "https://aur.archlinux.org/packages/$pkg"
    else
      echo "Open this page: https://aur.archlinux.org/packages/$pkg"
    fi
    exit 1
  fi
else
  echo "Skipped $pkg"
fi
