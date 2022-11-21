#!/bin/bash

# exit when any step fails
set -euo pipefail

# authenticate w/ sudo up-front
sudo -v

# ask for domain
read -p "👋  Hi! Enter your Mastodon server's domain or subdomain (without \"http\" or \"https\" - e.g. social.example): " MASTODON_DOMAIN

# initial ubuntu updates
export DEBIAN_FRONTEND=noninteractive
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget gnupg apt-transport-https lsb-release ca-certificates

# add node apt repository
curl -sL https://deb.nodesource.com/setup_16.x | sudo bash -

# add postgres apt repository
sudo wget -O /usr/share/keyrings/postgresql.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/postgresql.list

# install prerequisites:
# https://docs.joinmastodon.org/admin/install/#system-packages
sudo apt update
sudo apt install -y \
  imagemagick ffmpeg libpq-dev libxml2-dev libxslt1-dev file git-core \
  g++ libprotobuf-dev protobuf-compiler pkg-config nodejs gcc autoconf \
  bison build-essential libssl-dev libyaml-dev libreadline6-dev \
  zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev \
  nginx redis-server redis-tools postgresql postgresql-contrib \
  certbot python3-certbot-nginx libidn11-dev libicu-dev libjemalloc-dev

# setup yarn
sudo npm install --global yarn
sudo corepack enable
yarn set version classic

# install rbenv & ruby-build
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bash_profile
source ~/.bash_profile
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)/plugins/ruby-build"

# clone mastodon & checkout latest version
git clone https://github.com/mastodon/mastodon.git ~/live && cd ~/live
git checkout $(git tag -l | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)

# install ruby
RUBY_CONFIGURE_OPTS=--with-jemalloc rbenv install "$(cat ./.ruby-version)"
rbenv global "$(cat ./.ruby-version)"

# install npm and gem dependencies
gem install bundler --no-document
bundle config deployment "true"
bundle config without "development test"
bundle install -j$(getconf _NPROCESSORS_ONLN)
yarn install --pure-lockfile --network-timeout 100000

# set up database
echo "CREATE USER $(whoami) CREATEDB" | sudo -u postgres psql -f -

# run interactive mastodon wizard
RAILS_ENV=production bundle exec rake mastodon:setup

# order an ssl certificate from LE
sudo certbot certonly --nginx -d "$MASTODON_DOMAIN"

# configure nginx
sudo cp ./dist/nginx.conf "/etc/nginx/sites-available/$MASTODON_DOMAIN.conf"
sudo sed -i "/etc/nginx/sites-available/$MASTODON_DOMAIN.conf" -e "s/example.com/$MASTODON_DOMAIN/g"
sudo sed -i "/etc/nginx/sites-available/$MASTODON_DOMAIN.conf" -e "/ssl_certificate/s/^  #//"
sudo ln -s "/etc/nginx/sites-available/$MASTODON_DOMAIN.conf" "/etc/nginx/sites-enabled/$MASTODON_DOMAIN.conf"
sudo systemctl restart nginx

# enable systemd services on startup
sudo cp ./dist/mastodon-*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mastodon-web mastodon-sidekiq mastodon-streaming

echo "All done! Consider working on these highly recommended next steps:"
echo "https://github.com/jakejarvis/mastodon-installer#whats-next"
