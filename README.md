# DELICE

**D**ebian **L**inux **I**nstall **C**ustom **E**asy

Automated provisioning and maintenance toolkit for Debian with XFCE desktop environment. Supports
both fresh installations and upgrades on existing machines (Debian 12 -> 13) without data loss.

## Repository Structure

```treeview
delice/
├── post-install.sh           # Base system setup
├── desktop-environment.sh    # XFCE desktop installation
├── test-vm.sh               # Automated VM testing
├── sources.list             # Debian Trixie sources
├── lib/
│   └── common.sh            # Shared shell functions
├── configs/
│   ├── brave-policies-managed.json      # Brave enforced policies
│   └── brave-policies-recommended.json  # Brave recommended policies
├── tools/
│   └── migrate-chrome-to-brave.py       # Chrome data migration script
├── .config/                 # Application configs (alacritty, fastfetch, xfce4, etc.)
├── dotfiles/                # Shell dotfiles
└── wallpapers/              # Desktop backgrounds
```

## Installation Scripts

### post-install.sh

Base system configuration script that:

- Updates Debian sources from Bookworm to Trixie
- Installs essential packages and development tools
- Configures system services (chrony, ufw, iwd, ModemManager)
- Sets up firewall rules (deny incoming except SSH)
- Configures timezone (Europe/Paris) and NTP

```bash
./post-install.sh [--as-root] [--dry-run]
```

### desktop-environment.sh

XFCE desktop environment setup with interactive prompts or CLI flags.

```bash
./desktop-environment.sh [options]
```

**Options:**

| Flag                       | Description                                                  |
| -------------------------- | ------------------------------------------------------------ |
| `--no-prompts`             | Non-interactive mode (use defaults or CLI flags)             |
| `--theme`                  | Install theme packages and sync dotfiles                     |
| `--drivers=PROFILE`        | Driver profile: vm, intel, nvidia, none                      |
| `--with-brave`             | Install Brave browser with managed policies                  |
| `--migrate-chrome`         | Migrate Chrome data (bookmarks, history, passwords) to Brave |
| `--with-rustdesk`          | Install Rustdesk remote access                               |
| `--rustdesk-server=HOST`   | Rustdesk relay server address                                |
| `--rustdesk-key=KEY`       | Rustdesk server public key                                   |
| `--rustdesk-password=PASS` | Rustdesk permanent password                                  |
| `--with-office`            | Install office suite                                         |
| `--with-multimedia[=LIST]` | Install multimedia packages (players,editors,burn,ripencode) |
| `--with-development`       | Install development toolchain                                |
| `--enable-bluetooth`       | Install Bluetooth support                                    |
| `--backup-configs`         | Backup user configs before installing                        |
| `--skip-backup`            | Skip backup prompt for existing installations                |
| `--as-root`                | Run as root (testing only)                                   |
| `--dry-run`                | Show planned actions without executing                       |

**Features:**

- XFCE desktop with LightDM/Slick Greeter
- Dark theme: Arc-Dark (GTK) + KvArcDark (Qt/Kvantum)
- Video drivers: VM (SPICE/QXL), Intel, Nvidia
- Brave browser with enterprise policies (uBlock Origin forced, Rewards/Wallet/VPN disabled)
- Chrome to Brave migration (bookmarks, history, encrypted passwords)
- Rustdesk remote access with self-hosted server support
- Backup system for existing installations
- Selective config sync (no data loss on re-provisioning)

## Upgrade Existing Machines

DELICE can safely re-provision existing Debian installations:

```bash
# Backup configs, install desktop with Brave and Rustdesk
./desktop-environment.sh --backup-configs --theme --with-brave --with-rustdesk
```

The backup system saves user data (browser profiles, SSH keys, keyrings, LibreOffice config) to
`~/delice-backup-YYYYMMDD/` before applying changes. Config sync uses selective rsync per
subdirectory instead of `rsync --delete` on the entire `~/.config/`.

## Brave + Chrome Migration

When both Chrome and Brave are detected, DELICE offers automatic migration:

```bash
./desktop-environment.sh --with-brave --migrate-chrome
```

Or run the migration script standalone:

```bash
python3 tools/migrate-chrome-to-brave.py [--dry-run]
```

Migrates: bookmarks (JSON copy), history (SQLite copy), passwords (AES-128-CBC decrypt/re-encrypt
via GNOME Keyring).

**Requirements:** `python3-secretstorage`, `python3-cryptography`

## Testing

Automated VM testing using QEMU/KVM:

```bash
./test-vm.sh              # Test post-install.sh only
./test-vm.sh --desktop    # Test both scripts
```

**Requirements:** QEMU/KVM, libvirt, virt-install, virt-customize, virt-cat

The `VIRT_MANAGER_DIR` environment variable configures the VM storage path (default:
`/home/$USER/virt-manager`).

## Configuration Files

Pre-configured dotfiles and settings synced to `~/.config/`:

- **Alacritty**: Terminal emulator (`.config/alacritty/`)
- **Fastfetch**: System information display (`.config/fastfetch/`)
- **XFCE4**: Desktop, panel, keyboard shortcuts (`.config/xfce4/`)
- **GTK 2/3**: Theme and file chooser (`.config/gtk-2.0/`, `.config/gtk-3.0/`)
- **Kvantum**: Qt dark theme (`.config/Kvantum/`)
- **Rofi**: Application launcher (`.config/rofi/`)
- **htop**: System monitor (`.config/htop/`)

## System Requirements

- Debian 12 (Bookworm) or Debian 13 (Trixie) base installation
- Internet connection
- Sudo privileges
- Minimum 4GB disk space (8GB+ recommended with desktop)

## License

See [LICENSE](LICENSE)
