#!/usr/bin/env bash
set -e

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

if [ "$OS" = "darwin" ]; then
    OS="macos"
fi

if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    ARCH="aarch64"
elif [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ]; then
    ARCH="x86_64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

BINARY_NAME="teul-${OS}-${ARCH}"
DOWNLOAD_URL="https://github.com/ivanleomk/teul/releases/latest/download/${BINARY_NAME}"

INSTALL_DIR="$HOME/.local/bin"

echo "Downloading ${BINARY_NAME}..."
curl -sSL "$DOWNLOAD_URL" -o teul
chmod +x teul

mkdir -p "$INSTALL_DIR"
mv teul "$INSTALL_DIR/"

echo "Teul has been installed to $INSTALL_DIR/teul"
echo "Make sure $INSTALL_DIR is in your PATH."
