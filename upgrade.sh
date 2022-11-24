#!/bin/bash

# exit when any step fails
set -euo pipefail

# default paths
MASTODON_ROOT=/home/mastodon
RBENV_ROOT="$MASTODON_ROOT/.rbenv"

# check for existing installation
if [ ! -d "$MASTODON_ROOT/live" ]
then
  echo "$MASTODON_ROOT/live doesn't exist, are you sure Mastodon is installed?"
  exit 255
fi

# update ubuntu packages
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

# pull latest mastodon source
cd "$MASTODON_ROOT/live"
sudo -u mastodon git fetch --tags
sudo -u mastodon git checkout "$(sudo -u mastodon git tag -l | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)"

# set new ruby version
sudo -u mastodon RUBY_CONFIGURE_OPTS=--with-jemalloc "$RBENV_ROOT/bin/rbenv" install "$(cat $MASTODON_ROOT/live/.ruby-version)" || true
sudo -u mastodon "$RBENV_ROOT/bin/rbenv" global "$(cat $MASTODON_ROOT/live/.ruby-version)"

# update dependencies
sudo -u mastodon "$RBENV_ROOT/shims/bundle" install --jobs "$(getconf _NPROCESSORS_ONLN)"
sudo -u mastodon yarn install --pure-lockfile --network-timeout 100000

# run migrations:
# https://docs.joinmastodon.org/admin/upgrading/
sudo -u mastodon SKIP_POST_DEPLOYMENT_MIGRATIONS=true RAILS_ENV=production "$RBENV_ROOT/shims/bundle" exec rails db:migrate
sudo -u mastodon RAILS_ENV=production "$RBENV_ROOT/shims/bundle" exec rails assets:clobber
sudo -u mastodon RAILS_ENV=production "$RBENV_ROOT/shims/bundle" exec rails assets:precompile

# restart mastodon
sudo systemctl reload mastodon-web
sudo systemctl restart mastodon-sidekiq

# clear caches & run post-deployment db migration
sudo -u mastodon RAILS_ENV=production "$RBENV_ROOT/shims/ruby" "$MASTODON_ROOT/live/bin/tootctl" cache clear
sudo -u mastodon RAILS_ENV=production "$RBENV_ROOT/shims/bundle" exec rails db:migrate

# restart mastodon again
sudo systemctl reload mastodon-web
sudo systemctl restart mastodon-sidekiq

echo "All done! Check the latest release notes, there may be additional version-specific steps:"
echo "https://github.com/mastodon/mastodon/releases"
