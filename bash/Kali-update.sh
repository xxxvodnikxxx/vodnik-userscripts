#!/bin/bash

# ======================================================
# 📝 Raspberry Pi / Debian-based System Update Script
#
# This script:
#   - Checks if it is running as root (or with sudo)
#   - Updates the package lists (apt update)
#   - Lists any available upgradable packages
#   - Asks you if you want to upgrade them
#   - If yes:
#       * Performs full upgrade (apt full-upgrade -y)
#       * Removes unused packages (apt autoremove -y)
#       * Cleans up cached packages (apt clean)
#   - Otherwise, it exits safely
#
# ✅ Useful for quickly keeping your Pi system up to date!
#
# Author: xxxvodnikxxx
# Last update: 2025-07-04
# ======================================================

# Check if the script is running as root (or with sudo)
if [[ "$EUID" -ne 0 ]]; then
  echo "⚠️ You must run this script as root or using sudo!"
  exit 1
fi

echo "🔍 Checking for available updates..."
sudo apt update > /dev/null

# Get the list of upgradable packages (skip the header line)
UPGRADES=$(apt list --upgradable 2>/dev/null | tail -n +2)

if [[ -z "$UPGRADES" ]]; then
    echo "✅ The system is up to date. Nothing to upgrade."
    exit 0
else
    echo "📦 The following packages can be upgraded:"
    echo "$UPGRADES"
    echo
    read -p "❓ Do you want to upgrade them? [y/N] " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "🛠️  Starting the upgrade..."
        sudo apt full-upgrade -y
        sudo apt autoremove -y
        sudo apt clean
        echo "✅ Done!"
    else
        echo "🚫 Upgrade was canceled."
    fi
fi