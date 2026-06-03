#!/usr/bin/env sh
set -eu

ODOO_VERSION="${ODOO_VERSION:-19.0}"
ENTERPRISE_REPO="${ENTERPRISE_REPO:-git@github.com:odoo/enterprise.git}"
TARGET_DIR="${TARGET_DIR:-addons}"

if [ -d "$TARGET_DIR/.git" ]; then
  echo "Odoo Enterprise is already cloned in $TARGET_DIR."
  echo "Updating branch $ODOO_VERSION..."
  git -C "$TARGET_DIR" fetch origin "$ODOO_VERSION"
  git -C "$TARGET_DIR" checkout "$ODOO_VERSION"
  git -C "$TARGET_DIR" pull --ff-only origin "$ODOO_VERSION"
  exit 0
fi

if [ -e "$TARGET_DIR" ] && [ "$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" != "0" ]; then
  echo "Error: $TARGET_DIR already exists and is not empty."
  echo "Move it away or set TARGET_DIR to another path before running this script."
  exit 1
fi

mkdir -p "$TARGET_DIR"
rmdir "$TARGET_DIR"

echo "Cloning Odoo Enterprise $ODOO_VERSION into $TARGET_DIR..."
git clone --depth 1 --branch "$ODOO_VERSION" "$ENTERPRISE_REPO" "$TARGET_DIR"

echo "Done."
