#!/usr/bin/env python3

"""
Migrate Chrome data (bookmarks, history, passwords) to Brave browser.

Dependencies: python3-secretstorage, python3-cryptography
Usage: migrate-chrome-to-brave.py [--dry-run]
"""

import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

try:
  import secretstorage
except ImportError:
  print("Error: python3-secretstorage is required. Install with: sudo apt install python3-secretstorage")
  sys.exit(1)

try:
  from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
  from cryptography.hazmat.primitives import padding
except ImportError:
  print("Error: python3-cryptography is required. Install with: sudo apt install python3-cryptography")
  sys.exit(1)


CHROME_DIR = Path.home() / ".config" / "google-chrome" / "Default"
BRAVE_DIR = Path.home() / ".config" / "BraveSoftware" / "Brave-Browser" / "Default"

# Chromium on Linux uses PBKDF2 with these fixed parameters
PBKDF2_SALT = b"saltysalt"
PBKDF2_ITERATIONS = 1
PBKDF2_KEY_LENGTH = 16
AES_IV = b" " * 16  # 16 spaces
CHROMIUM_PASSWORD_PREFIX = b"v10"


def check_browser_running(process_name):
  """Check if a browser process is currently running."""
  try:
    result = subprocess.run(
      ["pgrep", "-f", process_name],
      capture_output=True, text=True
    )
    return result.returncode == 0
  except FileNotFoundError:
    return False


def get_encryption_key(application):
  """Read the encryption key from GNOME Keyring for a Chromium-based browser.

  Chrome stores under 'Chrome Safe Storage', Brave under 'Brave Safe Storage'.
  """
  connection = secretstorage.dbus_init()
  collection = secretstorage.get_default_collection(connection)

  if collection.is_locked():
    collection.unlock()

  for item in collection.get_all_items():
    if item.get_label() == f"{application} Safe Storage":
      secret = item.get_secret()
      return hashlib.pbkdf2_hmac(
        "sha1", secret, PBKDF2_SALT, PBKDF2_ITERATIONS, PBKDF2_KEY_LENGTH
      )

  return None


def get_chrome_key():
  """Read Chrome encryption key from GNOME Keyring."""
  return get_encryption_key("Chrome")


def get_brave_key():
  """Read Brave encryption key from GNOME Keyring."""
  return get_encryption_key("Brave")


def decrypt_password(encrypted, key):
  """Decrypt a Chromium-encrypted password using AES-128-CBC."""
  if not encrypted or not encrypted.startswith(CHROMIUM_PASSWORD_PREFIX):
    return None

  encrypted_data = encrypted[len(CHROMIUM_PASSWORD_PREFIX):]

  if not encrypted_data:
    return None

  cipher = Cipher(algorithms.AES(key), modes.CBC(AES_IV))
  decryptor = cipher.decryptor()
  decrypted_padded = decryptor.update(encrypted_data) + decryptor.finalize()

  # Remove PKCS7 padding
  unpadder = padding.PKCS7(128).unpadder()
  decrypted = unpadder.update(decrypted_padded) + unpadder.finalize()

  return decrypted.decode("utf-8")


def encrypt_password(plaintext, key):
  """Encrypt a password for a Chromium-based browser using AES-128-CBC."""
  padder = padding.PKCS7(128).padder()
  padded_data = padder.update(plaintext.encode("utf-8")) + padder.finalize()

  cipher = Cipher(algorithms.AES(key), modes.CBC(AES_IV))
  encryptor = cipher.encryptor()
  encrypted = encryptor.update(padded_data) + encryptor.finalize()

  return CHROMIUM_PASSWORD_PREFIX + encrypted


def backup_profiles(dry_run=False):
  """Backup Chrome and Brave profiles before migration."""
  timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
  backup_base = Path.home() / f"delice-migration-backup-{timestamp}"

  profiles = []
  if CHROME_DIR.exists():
    profiles.append(("chrome", CHROME_DIR))
  if BRAVE_DIR.exists():
    profiles.append(("brave", BRAVE_DIR))

  if dry_run:
    print(f"[DRY RUN] Would backup profiles to: {backup_base}")
    for name, path in profiles:
      print(f"  - {name}: {path}")
    return True

  print(f"Backing up profiles to: {backup_base}")
  backup_base.mkdir(parents=True, exist_ok=True)

  for name, path in profiles:
    dest = backup_base / name
    dest.mkdir(parents=True, exist_ok=True)
    for filename in ["Bookmarks", "History", "Login Data"]:
      src_file = path / filename
      if src_file.exists():
        shutil.copy2(src_file, dest / filename)
        print(f"  Backed up {name}/{filename}")

  print(f"Backup complete: {backup_base}")
  return True


def migrate_bookmarks(dry_run=False):
  """Migrate bookmarks from Chrome to Brave by copying the JSON file."""
  src = CHROME_DIR / "Bookmarks"
  dst = BRAVE_DIR / "Bookmarks"

  if not src.exists():
    print("No Chrome bookmarks found, skipping.")
    return 0

  if dry_run:
    with open(src, "r") as f:
      data = json.load(f)
    count = count_bookmarks(data.get("roots", {}))
    print(f"[DRY RUN] Would migrate {count} bookmarks")
    return count

  shutil.copy2(src, dst)
  with open(src, "r") as f:
    data = json.load(f)
  count = count_bookmarks(data.get("roots", {}))
  print(f"Migrated {count} bookmarks")
  return count


def count_bookmarks(node):
  """Recursively count bookmarks in a bookmarks JSON structure."""
  count = 0
  if isinstance(node, dict):
    if node.get("type") == "url":
      return 1
    for value in node.values():
      count += count_bookmarks(value)
  elif isinstance(node, list):
    for item in node:
      count += count_bookmarks(item)
  return count


def migrate_history(dry_run=False):
  """Migrate browsing history from Chrome to Brave by copying the SQLite database."""
  src = CHROME_DIR / "History"
  dst = BRAVE_DIR / "History"

  if not src.exists():
    print("No Chrome history found, skipping.")
    return 0

  # Count entries for reporting
  with tempfile.NamedTemporaryFile(suffix=".db") as tmp:
    shutil.copy2(src, tmp.name)
    conn = sqlite3.connect(tmp.name)
    count = conn.execute("SELECT COUNT(*) FROM urls").fetchone()[0]
    conn.close()

  if dry_run:
    print(f"[DRY RUN] Would migrate {count} history entries")
    return count

  shutil.copy2(src, dst)
  print(f"Migrated {count} history entries")
  return count


def migrate_passwords(chrome_key, brave_key, dry_run=False):
  """Migrate passwords: decrypt from Chrome, re-encrypt for Brave, insert into Brave DB."""
  src = CHROME_DIR / "Login Data"
  dst = BRAVE_DIR / "Login Data"

  if not src.exists():
    print("No Chrome passwords found, skipping.")
    return 0

  if not dst.exists():
    print("Brave Login Data not found. Launch Brave at least once first.")
    return 0

  # Read Chrome passwords from a temporary copy (avoid lock issues)
  with tempfile.NamedTemporaryFile(suffix=".db") as tmp:
    shutil.copy2(src, tmp.name)
    conn = sqlite3.connect(tmp.name)
    rows = conn.execute(
      "SELECT origin_url, action_url, username_value, password_value, signon_realm FROM logins"
    ).fetchall()
    conn.close()

  migrated = 0
  skipped = 0

  if dry_run:
    for origin_url, action_url, username, encrypted_pw, signon_realm in rows:
      decrypted = decrypt_password(encrypted_pw, chrome_key)
      if decrypted:
        migrated += 1
        print(f"  [DRY RUN] {origin_url} ({username})")
      else:
        skipped += 1
    print(f"[DRY RUN] Would migrate {migrated} passwords ({skipped} skipped)")
    return migrated

  # Work on a copy of Brave's Login Data
  with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tmp:
    tmp_path = tmp.name
    shutil.copy2(dst, tmp_path)

  conn = None
  try:
    conn = sqlite3.connect(tmp_path)

    for origin_url, action_url, username, encrypted_pw, signon_realm in rows:
      decrypted = decrypt_password(encrypted_pw, chrome_key)
      if not decrypted:
        skipped += 1
        continue

      # Check if this login already exists in Brave
      existing = conn.execute(
        "SELECT COUNT(*) FROM logins WHERE origin_url = ? AND username_value = ?",
        (origin_url, username)
      ).fetchone()[0]

      if existing > 0:
        skipped += 1
        continue

      re_encrypted = encrypt_password(decrypted, brave_key)

      conn.execute(
        "INSERT INTO logins (origin_url, action_url, username_value, password_value, "
        "signon_realm, date_created, blacklisted_by_user, scheme) "
        "VALUES (?, ?, ?, ?, ?, 0, 0, 0)",
        (origin_url, action_url, username, re_encrypted, signon_realm)
      )
      migrated += 1

    conn.commit()
    conn.close()

    # Replace Brave's Login Data with the modified copy
    shutil.move(tmp_path, dst)
    print(f"Migrated {migrated} passwords ({skipped} skipped/duplicates)")

  except Exception as e:
    if conn:
      conn.close()
    os.unlink(tmp_path)
    print(f"Error migrating passwords: {e}")
    return 0

  return migrated


def main():
  parser = argparse.ArgumentParser(
    description="Migrate Chrome data (bookmarks, history, passwords) to Brave browser."
  )
  parser.add_argument(
    "--dry-run", action="store_true",
    help="Show what would be migrated without making changes"
  )
  args = parser.parse_args()

  # Pre-flight checks
  if not CHROME_DIR.exists():
    print(f"Error: Chrome profile not found at {CHROME_DIR}")
    sys.exit(1)

  if not BRAVE_DIR.exists():
    print(f"Error: Brave profile not found at {BRAVE_DIR}")
    print("Launch Brave at least once to create the profile, then retry.")
    sys.exit(1)

  if check_browser_running("chrome"):
    print("Error: Google Chrome is running. Close it before migrating.")
    sys.exit(1)

  if check_browser_running("brave"):
    print("Error: Brave browser is running. Close it before migrating.")
    sys.exit(1)

  print("=== Chrome to Brave Migration ===")
  if args.dry_run:
    print("[DRY RUN MODE — no changes will be made]\n")

  # Backup before migration
  backup_profiles(dry_run=args.dry_run)
  print()

  # Migrate bookmarks
  migrate_bookmarks(dry_run=args.dry_run)
  print()

  # Migrate history
  migrate_history(dry_run=args.dry_run)
  print()

  # Migrate passwords
  chrome_key = get_chrome_key()
  brave_key = get_brave_key()

  if not chrome_key:
    print("Warning: Chrome encryption key not found in GNOME Keyring.")
    print("Password migration skipped.")
  elif not brave_key:
    print("Warning: Brave encryption key not found in GNOME Keyring.")
    print("Password migration skipped.")
  else:
    migrate_passwords(chrome_key, brave_key, dry_run=args.dry_run)

  print("\n=== Migration complete ===")


if __name__ == "__main__":
  main()
