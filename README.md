# Proxmox-Sync-Wildcard

**Automated Wildcard Certificate Sync for Proxmox VE**

---

## Overview

`Proxmox-Sync-Wildcard` is a Bash script designed to securely retrieve a wildcard TLS certificate for `example.com` from a remote Certificate Authority host and deploy it into a Proxmox VE clustered certificate store. The script uses SSH key-based authentication, maintains a complete backup of the Proxmox store, and reloads only the required service to minimize downtime.

## Features

* **SSH Key Authentication**: Secure, passwordless retrieval of certificates.
* **Full-Store Backup**: Archives the entire `/etc/pve/local` directory before deployment.
* **Atomic Deployment**: Ensures correct permissions and ownership for new certificates.
* **Minimal Service Impact**: Reloads only the `pveproxy` service to apply updates.
* **Error Checking**: Validates SSH connectivity, file existence, and root privileges.

## Prerequisites

* Proxmox VE cluster with write access to `/etc/pve/local`.
* SSH key pair set up on both the Proxmox host and the remote CA server.
* The `certsync` user on the CA host must have read access to `/etc/letsencrypt/live/example.com`.

## Configuration

1. **SSH Key**: Place your private key at the path specified by `SSH_KEY_PATH` (default: `/root/.ssh/id_rsa_proxmoxsync`).
2. **Remote Host Details**:

   * `REMOTE_HOST`: The CA host's address.
   * `REMOTE_USER`: SSH user (e.g., `certsync`).
   * `REMOTE_CERT_DIR`: Path to the Let's Encrypt live directory for `example.org`.
3. **Local Paths**:

   *  DOMAIN : Domain to be set and used for the certficate
   * `PVE_STORE`: Proxmox certificate store (`/etc/pve/local`).
   * `BACKUP_BASE`: Base directory for backups (default: `/root/backup/pve-local`).

## Usage

```bash
chmod +x sync.sh
sudo ./sync.sh
```

The script will perform the following steps:

1. **Validate** root privileges and SSH key readability.
2. **Test** SSH connectivity to the CA server.
3. **Archive** the existing `/etc/pve/local` directory to a timestamped `.tar.gz`.
4. **Download** `fullchain.pem` and `privkey.pem` from the CA host.
5. **Verify** that both files are non-empty.
6. **Deploy** the new certificates into `/etc/pve/local` with the correct permissions (`0640`, `root:www-data`).
7. **Reload** the `pveproxy` service.
8. **Report** success and the backup location.

## Logging & Error Handling

* Errors are reported to STDERR, and the script exits with a non-zero code.
* All critical operations are wrapped in validation checks to prevent partial failures.

## Integration

Integrate into your automation pipeline using cron or Ansible:

```cron
0 3 * * * /root/sync.sh >> /var/log/proxmox-cert-sync.log 2>&1
```

## License

This script is provided under the AGPL 3.0 License. See LICENSE file for details.
