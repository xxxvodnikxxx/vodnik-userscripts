#!/bin/bash

# ======================================================
# 📝 Raspberry Pi EEPROM Backup & Restore Script
#
# This script allows you to:
#   1) Backup current Raspberry Pi EEPROM firmware to a timestamped file
#   2) Restore Raspberry Pi EEPROM firmware from a chosen backup file
#
# Author: xxxvodnikxxx
# Last update: 2025-07-04
# ======================================================

BACKUP_DIR="$HOME/rpi_eeprom_backups"

# Ensure running as root
if [[ "$EUID" -ne 0 ]]; then
  echo "⚠️ You must run this script as root (sudo)!"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "❓ What do you want to do?"
echo "1) Backup current EEPROM"
echo "2) Restore EEPROM from backup"
read -p "Select option [1/2]: " choice

if [[ "$choice" == "1" ]]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  BACKUP_FILE="$BACKUP_DIR/eeprom_backup_$TIMESTAMP.bin"
  
  echo "💾 Backing up current EEPROM to $BACKUP_FILE ..."
  
  # The EEPROM binary file location can vary depending on Pi model and OS
  # Typical path for Raspberry Pi 4+ bootloader:
  EEPROM_PATH="/lib/firmware/raspberrypi/bootloader/stable/pieeprom.bin"
  
  if [[ ! -f "$EEPROM_PATH" ]]; then
    echo "❌ EEPROM firmware file not found at $EEPROM_PATH"
    echo "Try to locate the EEPROM binary manually."
    exit 2
  fi
  
  cp "$EEPROM_PATH" "$BACKUP_FILE"
  
  if [[ $? -eq 0 ]]; then
    echo "✅ Backup successful!"
  else
    echo "❌ Backup failed!"
  fi

elif [[ "$choice" == "2" ]]; then
  echo "📂 Available backup files:"
  ls -1 "$BACKUP_DIR"
  
  read -p "Enter the exact filename to restore: " restore_file
  
  FULL_PATH="$BACKUP_DIR/$restore_file"
  
  if [[ ! -f "$FULL_PATH" ]]; then
    echo "❌ Backup file '$restore_file' not found!"
    exit 3
  fi
  
  echo "⚠️ You are about to restore EEPROM from '$restore_file'. This may brick your device if wrong!"
  read -p "Are you sure? Type 'YES' to proceed: " confirm
  
  if [[ "$confirm" == "YES" ]]; then
    echo "🔄 Restoring EEPROM ..."
    rpi-eeprom-update -d -f "$FULL_PATH"
    if [[ $? -eq 0 ]]; then
      echo "✅ EEPROM restore command issued. Please reboot your Raspberry Pi to apply changes."
    else
      echo "❌ EEPROM restore failed."
    fi
  else
    echo "🚫 Restore cancelled."
  fi
  
else
  echo "❌ Invalid option."
  exit 4
fi