#!/bin/bash

# exit when any step fails
set -euo pipefail

# default paths
MASTODON_ROOT=/home/mastodon
APP_ROOT="$MASTODON_ROOT/live"
BACKUPS_ROOT="$MASTODON_ROOT/backups"

if [ "$(systemctl is-active mastodon-web.service)" = "active" ]
then
  echo "⚠️  Mastodon is currently running."
  echo "We'll start the backup anyways, but if it's a critical one, stop all Mastodon"
  echo "services first with 'systemctl stop mastodon-*' and run this again."
  echo ""
fi

if [ ! -d "$BACKUPS_ROOT" ]
then
  sudo mkdir -p "$BACKUPS_ROOT"
  sudo chown -R mastodon:mastodon "$BACKUPS_ROOT"
fi

TEMP_DIR=$(sudo -u mastodon mktemp -d)

echo "Backing up Postgres..."
sudo -u mastodon pg_dump -Fc mastodon_production -f "$TEMP_DIR/postgres.dump"

echo "Backing up Redis..."
sudo cp /var/lib/redis/dump.rdb "$TEMP_DIR/redis.rdb"

echo "Backing up secrets..."
sudo cp "$MASTODON_ROOT/live/.env.production" "$TEMP_DIR/env.production"

echo "Compressing..."
ARCHIVE_DEST="$BACKUPS_ROOT/$(date "+%Y.%m.%d-%H.%M.%S").tar.gz"
sudo tar --owner=0 --group=0 -czvf "$ARCHIVE_DEST" -C "$TEMP_DIR" .
sudo chown mastodon:mastodon "$ARCHIVE_DEST"

sudo rm -rf --preserve-root "$TEMP_DIR"

echo "Saved to $ARCHIVE_DEST"
echo "🎉 All done! (Keep this archive safe!)"
