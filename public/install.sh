#!/usr/bin/env bash
# Lore CLI installer
# Usage: curl -s https://lore.sh/install.sh | bash

set -e

INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"

echo "Installing Lore CLI..."
curl -sf "https://lore.sh/lore" -o "${INSTALL_DIR}/lore"
chmod +x "${INSTALL_DIR}/lore"

# Ensure install dir is in PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "Note: Add this to your shell profile:"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo "✓ Installed to ${INSTALL_DIR}/lore"
echo ""
echo "Next steps:"
echo "  lore register <your-agent-name>"
echo "  lore search \"send slack notification\""
