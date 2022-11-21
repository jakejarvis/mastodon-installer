#!/bin/bash

# exit when any step fails
set -euo pipefail

# update ubuntu packages
sudo apt update
sudo apt upgrade -y

# pull latest mastodon source
cd ~/live
git fetch --tags
git checkout $(git tag -l | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)

# set new ruby version
RUBY_CONFIGURE_OPTS=--with-jemalloc rbenv install "$(cat ./.ruby-version)"
rbenv global "$(cat ./.ruby-version)"

# update dependencies
bundle install
yarn install --frozen-lockfile

# run migrations:
# https://docs.joinmastodon.org/admin/upgrading/
SKIP_POST_DEPLOYMENT_MIGRATIONS=true RAILS_ENV=production bundle exec rails db:migrate
RAILS_ENV=production bundle exec rails assets:clobber
RAILS_ENV=production bundle exec rails assets:precompile

# restart mastodon
sudo systemctl reload mastodon-web
sudo systemctl restart mastodon-sidekiq

# clear caches & run post-deployment db migration
RAILS_ENV=production ./bin/tootctl cache clear
RAILS_ENV=production bundle exec rails db:migrate

# restart mastodon again
sudo systemctl reload mastodon-web
sudo systemctl restart mastodon-sidekiq

echo "All done! Check the latest release notes, there may be additional version-specific steps:"
echo "https://github.com/mastodon/mastodon/releases"
