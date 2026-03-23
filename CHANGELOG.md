# Changelog

## v2.0 — Provisioning Toolkit

Evolution of DELICE from a fresh installation tool to a provisioning and maintenance
toolkit capable of running on existing Debian machines (12 -> 13) without data loss.

### Foundations

- Extract shared functions into `lib/common.sh`
- Refactor `post-install.sh`: error handling, quoted variables, `--dry-run` support
- Remove dead code from `desktop-environment.sh`

### Upgrade Safety

- User config backup system (`~/delice-backup-YYYYMMDD/`)
- Selective per-subdirectory sync instead of `rsync --delete` on `~/.config/`
- `--backup-configs` and `--skip-backup` flags

### Brave Browser

- APT repo installation with GPG keyring (`--with-brave`)
- Managed policies: Rewards/Wallet/VPN disabled, uBlock Origin force-installed
- Recommended policies: DuckDuckGo, Shields, AI Chat off by default
- Chrome uninstall prompt

### Chrome Migration

- Python script `tools/migrate-chrome-to-brave.py`
- Migrate bookmarks (JSON), history (SQLite), passwords (AES-128-CBC)
- Decrypt Chrome passwords via GNOME Keyring, re-encrypt for Brave
- `--dry-run` mode and automatic profile backup
- `--migrate-chrome` flag in `desktop-environment.sh`

### Rustdesk

- Install from GitHub releases (`--with-rustdesk`)
- Configure server ID, relay, public key, permanent password
- Defaults to self-hosted server laura.lgdweb.ovh

### Dark Theme

- Fix `QT_QPA_PLATFORMTHEME=kvantum` in `.profile`
- Kvantum config with KvArcDark theme
- Dotfiles cleanup (duplicates, unused shebang, empty case)

### Wallpaper

- `DELICE_WALLPAPER` placeholder in `xfce4-desktop.xml`
- Dynamic path resolution via `configureWallpaper()` at install time

### Test Framework

- Configurable VM paths via `VIRT_MANAGER_DIR` env var
- Remove dead code (unused variables, functions)
- Inject new `configs/` and `tools/` directories into test VM
- Clean up temporary files in trap handler

### Documentation

- Updated README with all new flags and features
- Created CHANGELOG
