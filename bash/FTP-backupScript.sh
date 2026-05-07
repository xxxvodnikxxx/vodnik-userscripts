#!/bin/bash

# =========================================
# === Backup script using lftp mirror ===
# =========================================

: <<'COMMENT'
    Script for automated FTP backup using lftp mirror. 
    It creates daily dated folders, copies previous backups to save bandwidth,
    and excludes specified directories from the backup.

    Requirements:
    - lftp installed on the system.
    - Proper FTP credentials.
    @author: xxxvodnikxxx
    @version 1.0

    Last rev. update: 07.05.2026
COMMENT


# === Configuration ===

## FTP credentials
HOST='ftp.example.com'
USER='username'
PASSWD='hardcodedPWDForAutomation'   # Hardcoded password (leave empty to be prompted)

## Locations
DEST_DIR='/home/myUser/localBackupPAth'   # Local backup base directory
FTP_FOLDER='www'                          # FTP folder to mirror

# === Excluded directories on FTP ===
EXCLUDES=(
    'subdom'
    'domains'
)

# =========================================
# === Variables ===
# =========================================
TODAY=$(date +%F)
TODAY_DIR="$DEST_DIR/$TODAY"

# =========================================
# === Functions ===
# =========================================

# --- Prompt for FTP password if not set ---
check_password() {
    if [ -z "$PASSWD" ]; then
        read -s -p "Enter FTP password for user $USER: " PASSWD
        echo
    fi
}

# --- Find the latest dated folder with FTP files ---
find_latest_ftp_backup_folder() {
    local latest_dir=""
    local dir

    while IFS= read -r dir; do
        if [ -d "$dir/FTP/$FTP_FOLDER" ] && find "$dir/FTP/$FTP_FOLDER" -type f -print -quit | grep -q .; then
            latest_dir="$dir"
            break
        fi
    done < <(find "$DEST_DIR" -maxdepth 1 -type d -name "20[0-9][0-9]-*" | sort -r)

    if [ -n "$latest_dir" ]; then
        echo "$latest_dir"
        return 0
    else
        return 1
    fi
}

# --- Prepare today's folder (always create, no confirmation) ---
prepare_today_folder() {
    echo "📂 Preparing today's folder: $TODAY_DIR/FTP/$FTP_FOLDER"
    mkdir -p "$TODAY_DIR/FTP/$FTP_FOLDER"
}

# --- Copy only the FTP subfolder from the last backup ---
copy_previous_backup() {
    local src_dir="$1"

    echo "📁 Copying FTP backup from $src_dir to $TODAY_DIR..."
    mkdir -p "$TODAY_DIR/FTP"
    cp -r "$src_dir/FTP/." "$TODAY_DIR/FTP/" 2>/dev/null
    echo "✅ Previous backup copied."
}

# --- Perform FTP mirror using lftp ---
ftp_mirror() {
    echo "🌐 Starting FTP mirror from $HOST..."

    local exclude_args=()
    for ex in "${EXCLUDES[@]}"; do
        exclude_args+=(--exclude "$ex")
    done

    lftp -u "$USER","$PASSWD" "$HOST" <<EOT
set ftp:list-options -a
set ssl:verify-certificate no
mirror --verbose --only-newer --parallel=2 \
       --exclude-glob .DS_Store \
       ${exclude_args[*]} \
       /$FTP_FOLDER "$TODAY_DIR/FTP/$FTP_FOLDER"
bye
EOT

    echo "✅ FTP mirror completed."
}

# --- Cleanup sensitive data ---
cleanup() {
    unset PASSWD
    echo "🔒 FTP password cleared from memory."
}

# =========================================
# === Main execution ===
# =========================================
main() {
    check_password
    prepare_today_folder

    local latest
    if latest=$(find_latest_ftp_backup_folder); then
        echo "✅ Latest backup found: $latest"
        copy_previous_backup "$latest"
    else
        echo "⚠️  No previous FTP backup found, creating new structure."
        mkdir -p "$TODAY_DIR/FTP/$FTP_FOLDER"
    fi

    ftp_mirror
    cleanup

    echo "✅ All done! Backup saved to: $TODAY_DIR/FTP/$FTP_FOLDER"
}

## Execute main function
main "$@"