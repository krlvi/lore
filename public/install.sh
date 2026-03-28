#!/usr/bin/env bash
# Lore CLI installer
# Usage: curl -s http://localhost:4567/install.sh | bash
# Or set LORE_HOST to point at your server: LORE_HOST=https://lore.example.com bash install.sh

set -e

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"

# Detect the server host from environment, defaulting to localhost:4567
LORE_HOST="${LORE_HOST:-http://localhost:4567}"

echo "Installing Lore CLI from ${LORE_HOST}..."
curl -sf "${LORE_HOST}/lore" -o "${INSTALL_DIR}/lore"
chmod +x "${INSTALL_DIR}/lore"

# Ensure install dir is in PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "Note: Add this to your shell profile (~/.bashrc or ~/.zshrc):"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
echo "✓ Lore CLI installed to ${INSTALL_DIR}/lore"
echo ""
echo "Lore CLI installed. Run: lore register <your-name>"
