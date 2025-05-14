#!/usr/bin/env bash
# =============================================================================
# Title:        Proxmox-Sync-Wildcard
# Description:  Automated retrieval from another proxy/CA and deployment
#               of wildcard TLS cert into Proxmox PVEProxy.
# Author:       0n1cOn3
# Date:         14-05-2025
# Version:      1.0.0
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# --- Configuration -----------------------------------------------------------

DOMAIN="example.com"
# Remote host SSH alias or IP where the certificate is provisioned
REMOTE_HOST="ca.internal.$DOMAIN"
REMOTE_USER="certsync"

# Remote directory containing Let's Encrypt output for example.com
REMOTE_CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
SSH_KEY_PATH="/root/.ssh/id_rsa_proxmoxsync"

# Local Proxmox certificate directory (managed via PVE filesystem)
PVE_STORE="/etc/pve/local"
BACKUP_BASE="/root/backup/pve-local"
TIMESTAMP=$(date +%F_%H%M%S)

# SSH options for SSH key, timeout, non-interactive, strict host checking
SSH_OPTS=(
  -i "$SSH_KEY_PATH"
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=yes
)

# Has the script run as root? No? Rerun as root. | Yes? Let's go ahead! :)
[[ "$EUID" -eq 0 ]] || { echo "ERROR: Must be run as root. Aborting."; exit 1; }

if [[ ! -r "$SSH_KEY_PATH" ]]; then
  echo "ERROR: SSH key not found or not readable at $SSH_KEY_PATH. Aborting." >&2
  exit 2
fi

# Verify SSH connectivity
ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" true &>/dev/null || {
  echo "ERROR: SSH key authentication to ${REMOTE_USER}@${REMOTE_HOST} failed." >&2
  exit 3
}

[[ -d "$PVE_STORE" ]] || { echo "ERROR: Proxmox store $PVE_STORE not found." >&2; exit 4; }

# --- Backup Existing Certificates --------------------------------------------
BACKUP_DIR="${BACKUP_BASE}/${TIMESTAMP}"
mkdir -p "$BACKUP_BASE"
echo ">> Archiving $PVE_STORE to ${BACKUP_DIR}.tar.gz"
tar czf "${BACKUP_DIR}.tar.gz" -C "$(dirname "$PVE_STORE")" "$(basename "$PVE_STORE")"

TMP_CRT="/tmp/example.fullchain.pem"
TMP_KEY="/tmp/example.privkey.pem"

# --- Fetch Remote Certificates -----------------------------------------------
echo ">> Fetching wildcard certificate from ${REMOTE_HOST}, Domain: $DOMAIN"
scp "${SSH_OPTS[@]}" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_CERT_DIR}/fullchain.pem" "$TMP_CRT"
scp "${SSH_OPTS[@]}" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_CERT_DIR}/privkey.pem" "$TMP_KEY"

# --- Validation & Deployment ------------------------------------------------
for f in "$TMP_CRT" "$TMP_KEY"; do
  [[ -s "$f" ]] || { echo "ERROR: Retrieved file $f is empty or missing." >&2; exit 5; }
done

# Basic sanity checks
echo ">> Installing new certificates into $PVE_STORE"
sudo cp "$TMP_CRT" "$PVE_STORE/pve-ssl.pem"
chmod 0640 "$PVE_STORE/pve-ssl.pem"
sudo cp "$TMP_KEY" "$PVE_STORE/pve-ssl.key"
chmod 0640 "$PVE_STORE/pve-ssl.key"
#install -o root -g www-data -m 0640 "$TMP_CRT" "$PVE_STORE/pve-ssl.pem"
#install -o root -g www-data -m 0640 "$TMP_KEY" "$PVE_STORE/pve-ssl.key"

# Cleanup leftover temp files
rm -f "$TMP_CRT" "$TMP_KEY"

# Reload PVEProxy
echo ">> Reloading Proxmox proxy service to apply updated cert"
sudo systemctl reload pveproxy

# We're done
echo ">> SUCCESS: $DOMAIN wildcard certificate deployed; backup at ${BACKUP_DIR}.tar.gz"
