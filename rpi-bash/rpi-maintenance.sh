#!/bin/bash

# Raspberry Pi Update and EEPROM Restore Script

# ====== CONFIGURATION ======
BACKUP_DIR="/home/shared/rpi/eeprom_backups"
LOGFILE="/var/log/pi-update.log"
# ===========================

# Color functions
green()  { echo -e "\033[1;32m$1\033[0m"; }
yellow() { echo -e "\033[1;33m$1\033[0m"; }
red()    { echo -e "\033[1;31m$1\033[0m"; }

# Check if running as root
if [[ "$EUID" -ne 0 ]]; then
  red "⚠️ You must run this script as root or using sudo!"
  exit 1
fi

# Create backup directory if not exists
mkdir -p "$BACKUP_DIR"

# Ask what to do
echo "❓ What do you want to do?"
echo "1) Update system and optionally update EEPROM (default)"
echo "2) Restore EEPROM backup"
read -p "Select option [1/2]: " MODE

if [[ "$MODE" == "2" ]]; then
    echo "💽 Available backups in $BACKUP_DIR:"
    ls "$BACKUP_DIR"
    echo
    read -p "Enter the filename to restore: " RESTORE_FILE

    if [[ -f "$BACKUP_DIR/$RESTORE_FILE" ]]; then
        echo "⚠️ About to restore EEPROM from $RESTORE_FILE"
        read -p "Are you sure? This may brick your Pi if wrong file! [y/N] " CONFIRM_RESTORE
        if [[ "$CONFIRM_RESTORE" =~ ^[Yy]$ ]]; then
            cp "$BACKUP_DIR/$RESTORE_FILE" /tmp/pieeprom.bin
            rpi-eeprom-update -d -f /tmp/pieeprom.bin
            green "✅ EEPROM restore command issued. Please reboot to apply."
        else
            red "🚫 Restore cancelled."
        fi
    else
        red "❌ Backup file not found!"
    fi
    exit 0
fi

# Default: UPDATE MODE
echo "[$(date)] Starting update..." >> $LOGFILE

echo "🔍 Checking free space on /boot..."
BOOT_FREE=$(df /boot | awk 'NR==2 {print $4}')
if (( BOOT_FREE < 10000 )); then
    yellow "⚠️ Warning: Less than 10 MB free in /boot. Kernel update might fail."
fi

echo "🔎 Updating package lists..."
apt update | tee -a $LOGFILE

# Get upgradable packages
UPGRADES=$(apt list --upgradable 2>/dev/null | tail -n +2)

if [[ -z "$UPGRADES" ]]; then
    green "✅ The system is up to date. Nothing to upgrade."
    echo "[$(date)] System up to date." >> $LOGFILE
else
    yellow "📦 The following packages can be upgraded:"
    echo "$UPGRADES"
    echo
    read -p "❓ Do you want to upgrade them now? [y/N] " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "🛠️  Starting full upgrade..."
        apt full-upgrade -y | tee -a $LOGFILE
        apt autoremove -y | tee -a  $LOGFILE
        apt clean | tee -a $LOGFILE
        green "✅ Upgrade complete!"
    else
        red "🚫 Upgrade canceled by user."
        echo "[$(date)] Upgrade canceled." >> $LOGFILE
        exit 0
    fi
fi

# EEPROM update (for Pi 4+)
if command -v rpi-eeprom-update >/dev/null 2>&1; then
    read -p "💾 Do you want to update the Raspberry Pi EEPROM firmware? [y/N] " FIRM_CONFIRM
    if [[ "$FIRM_CONFIRM" =~ ^[Yy]$ ]]; then

        # Offer to back up current EEPROM
        read -p "💽 Do you want to back up the current EEPROM first? [Y/n] " BACKUP_CONFIRM
        # overwrite default- empty value -> in case not selected, make backup as default
        BACKUP_CONFIRM=${BACKUP_CONFIRM:-Y}
        
        if [[ "$BACKUP_CONFIRM" =~ ^[Yy]$ ]]; then
            BACKUP_PATH="$BACKUP_DIR/eeprom_backup_$(date +%Y%m%d_%H%M%S).bin"
            echo "📥 Backing up current EEPROM to $BACKUP_PATH"
            cp /lib/firmware/raspberrypi/bootloader/stable/pieeprom-*.bin "$BACKUP_PATH"
            green "✅ EEPROM backup saved as $BACKUP_PATH"
        else
            yellow "⚠️ Skipping EEPROM backup."
        fi

        rpi-eeprom-update -a >> $LOGFILE
        green "✅ EEPROM update command issued. Reboot required to apply."
    else
        yellow "⚠️ EEPROM update skipped."
    fi
fi

echo "[$(date)] Update finished." >> $LOGFILE
green "🎉 All done! Check $LOGFILE for details if needed."