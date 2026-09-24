#!/bin/bash
set -euo pipefail

show_help() {
  cat <<EOF

Description:
  Download Ubuntu packages (.deb) and all dependencies for offline installation by 'apt-rdepends'.

  Default Output Directory:
  ./offline-packages

  IMPORTANT:
  - The downloaded packages are tied to the Ubuntu version and architecture of the system where this script is executed.
  - Make sure the download environment matches the target offline system (e.g., Ubuntu 22.04 ↔ 22.04, 24.04 ↔ 24.04).
  - Do NOT use packages downloaded from a different Ubuntu release, as this may cause dependency conflicts or installation failures.
  - Kernel headers must match the exact kernel version of the target system when building kernel modules.

Usage:
  bash $0 <package_name> [--dest <download_directory>]

Example:
  bash $0 build-essential --dest ./offline-packages
  bash $0 linux-headers-\$(uname -r) --dest ./pkg

Help:
  bash $0 --help[-h]

EOF
  exit 0
}

# Default output directory
OUTDIR=./offline-packages

# bash apt-rdepends_downloader.sh --help[-h]
if [ $# -lt 1 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  show_help
fi

PKG="$1"
shift

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)
      OUTDIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown Option: $1"
      show_help
      ;;
  esac
done

echo "========== Target Package: $PKG =========="
echo "========== Output Directory: $OUTDIR =========="

# Update apt list
echo "[1/4] Updating apt list"
sudo apt update

# Install apt-rdepends (if not installed)
if ! command -v apt-rdepends >/dev/null 2>&1; then
  echo "[2/4] Installing 'apt-rdepends'"
  sudo apt install -y apt-rdepends
else
  echo "[2/4] 'apt-rdepends' already installed"
fi

# Generate dependencies list
DEPS_FILE=$(mktemp)
echo "[3/4] Generating dependencies list"
if ! apt-cache show "$PKG" >/dev/null 2>&1; then
  echo "Error: Package '$PKG' does not exist in apt repositories."
  echo -e "Please check the package name.\n"
  exit 1
fi

apt-rdepends "$PKG" > "$DEPS_FILE"

# Download all dependencies
echo "[4/4] Downloading all dependencies"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

grep -v "^ " "$DEPS_FILE" | while read pkg; do
  echo "Downloading: $pkg"
  apt-get download "$pkg" || echo "Download failed, skipping: $pkg"
done

echo "========== Done =========="
echo -e "All packages are saved to: $OUTDIR\n"
