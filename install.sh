#!/bin/bash

# exit when any step fails
set -euo pipefail

# default paths
MASTODON_ROOT=/home/mastodon
RBENV_ROOT="$MASTODON_ROOT/.rbenv"

# check for existing installation
if [ -d "$MASTODON_ROOT/live" ]
then
  echo "$MASTODON_ROOT/live exists. Are you sure Mastodon isn't already installed?"
  exit 255
fi

# ask for required info up-front
# TODO: run some basic input validation?
echo -e "👋  Hi, just a few questions to get your very own Mastodon server up and running! \n"
read -p "What's your server's domain or subdomain (without \"http\" or \"https\" - e.g. social.example)? " MASTODON_DOMAIN
read -p "What's a good email address to use for server things? " MASTODON_ADMIN_EMAIL
read -p "What would you like the server administrator's Mastodon username to be? " MASTODON_ADMIN_USERNAME

# set FQDN (especially necessary for sendmail)
echo -e "\n# Added by mastodon-installer @ $(date)
127.0.0.1  localhost $MASTODON_DOMAIN
::1  localhost $MASTODON_DOMAIN" | sudo tee -a /etc/hosts >/dev/null
sudo hostnamectl set-hostname "$MASTODON_DOMAIN" || true

# create non-root mastodon user
sudo adduser --disabled-login --gecos "Mastodon" mastodon || true

# install latest ubuntu updates
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
  curl \
  wget \
  gnupg \
  apt-transport-https \
  lsb-release \
  ca-certificates

# add nodesource apt repository
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/nodesource-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/nodesource-archive-keyring.gpg] https://deb.nodesource.com/node_16.x $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null

# add official postgresql apt repository
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/postgresql.list >/dev/null

# add official redis apt repository
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list >/dev/null

# add official nginx apt repository
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu/ $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null

# install prerequisites:
# https://docs.joinmastodon.org/admin/install/#system-packages
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
  git-core \
  g++ \
  libpq-dev \
  libxml2-dev \
  libxslt1-dev \
  imagemagick \
  nodejs \
  redis-server \
  redis-tools \
  postgresql \
  postgresql-contrib \
  libidn11-dev \
  libicu-dev \
  libreadline6-dev \
  autoconf \
  bison \
  build-essential \
  ffmpeg \
  file \
  gcc \
  libffi-dev \
  libgdbm-dev \
  libjemalloc-dev \
  libncurses5-dev \
  libprotobuf-dev \
  libssl-dev \
  libyaml-dev \
  pkg-config \
  protobuf-compiler \
  zlib1g-dev \
  sendmail \
  nginx \
  python3 \
  python3-venv \
  libaugeas0

# setup yarn
sudo npm install --global yarn
sudo corepack enable

# install rbenv & ruby-build
sudo git clone https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
sudo git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' | sudo tee -a "$MASTODON_ROOT/.bash_profile" >/dev/null

# clone mastodon & checkout latest version
sudo -u mastodon git clone https://github.com/mastodon/mastodon.git "$MASTODON_ROOT/live" && cd "$MASTODON_ROOT/live"
sudo -u mastodon git checkout "$(sudo -u mastodon git tag -l | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)"
sudo git config --global --add safe.directory "$MASTODON_ROOT/live"

# permission fixes
sudo chown -R mastodon:mastodon "$MASTODON_ROOT/live" "$RBENV_ROOT"

# install ruby
RUBY_VERSION="$(sudo -u mastodon cat $MASTODON_ROOT/live/.ruby-version)"
sudo -u mastodon RUBY_CONFIGURE_OPTS=--with-jemalloc "$RBENV_ROOT/bin/rbenv" install "$RUBY_VERSION" || true
sudo -u mastodon "$RBENV_ROOT/bin/rbenv" global "$RUBY_VERSION"

# install npm and gem dependencies
sudo -u mastodon "$RBENV_ROOT/shims/gem" install bundler --no-document
sudo -u mastodon "$RBENV_ROOT/shims/bundle" config deployment "true"
sudo -u mastodon "$RBENV_ROOT/shims/bundle" config without "development test"
sudo -u mastodon "$RBENV_ROOT/shims/bundle" install --jobs "$(getconf _NPROCESSORS_ONLN)"
sudo -u mastodon yarn set version classic
sudo -u mastodon yarn install --pure-lockfile --network-timeout 100000

# set up database w/ random alphanumeric password
DB_PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c32; echo)
echo "CREATE USER mastodon WITH PASSWORD '$DB_PASSWORD' CREATEDB" | sudo -u postgres psql -f -

# populate .env.production config
echo "# Generated by mastodon-installer @ $(date)

LOCAL_DOMAIN=$MASTODON_DOMAIN
DB_HOST=localhost
DB_USER=mastodon
DB_NAME=mastodon_production
DB_PASS=$DB_PASSWORD
DB_PORT=5432
REDIS_HOST=localhost
REDIS_PORT=6379
SECRET_KEY_BASE=$(sudo -u mastodon RAILS_ENV=production "$RBENV_ROOT/shims/bundle" exec rake secret)
OTP_SECRET=$(sudo -u mastodon RAILS_ENV=production "$RBENV_ROOT/shims/bundle" exec rake secret)
$(sudo -u mastodon RAILS_ENV=production "$RBENV_ROOT/shims/bundle" exec rake mastodon:webpush:generate_vapid_key)

# -----------------------
# Add/modify additional config here, see https://docs.joinmastodon.org/admin/config/
# -----------------------
SINGLE_USER_MODE=false
IP_RETENTION_PERIOD=31556952
SESSION_RETENTION_PERIOD=31556952
SMTP_SERVER=localhost
SMTP_PORT=25
SMTP_AUTH_METHOD=none
SMTP_OPENSSL_VERIFY_MODE=none
SMTP_ENABLE_STARTTLS=auto
SMTP_FROM_ADDRESS=notifications@$MASTODON_DOMAIN
# SMTP_LOGIN=
# SMTP_PASSWORD=
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# S3_ENABLED=true
# S3_BUCKET=files.$MASTODON_DOMAIN
# S3_ALIAS_HOST=files.$MASTODON_DOMAIN
# ES_ENABLED=true
# ES_HOST=localhost
# ES_PORT=9200
# ES_USER=optional
# ES_PASS=optional" | sudo -u mastodon tee "$MASTODON_ROOT/live/.env.production" >/dev/null

# manually setup db
sudo -u mastodon RAILS_ENV=production "$RBENV_ROOT/shims/bundle" exec rails db:setup

# manually precompile assets
sudo -u mastodon RAILS_ENV=production "$RBENV_ROOT/shims/bundle" exec rails assets:precompile

# install latest certbot
# https://certbot.eff.org/instructions?ws=nginx&os=pip
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot

# order an ssl certificate from LE
sudo certbot certonly \
  --non-interactive \
  --agree-tos \
  --no-eff-email \
  --email "$MASTODON_ADMIN_EMAIL" \
  --domains "$MASTODON_DOMAIN" \
  --nginx

# configure nginx
sudo sed -i /etc/nginx/nginx.conf -e "s/user www-data;/user mastodon;/g"
sudo cp "$MASTODON_ROOT/live/dist/nginx.conf" "/etc/nginx/sites-available/$MASTODON_DOMAIN.conf"
sudo sed -i "/etc/nginx/sites-available/$MASTODON_DOMAIN.conf" -e "s/example.com/$MASTODON_DOMAIN/g"
sudo sed -i "/etc/nginx/sites-available/$MASTODON_DOMAIN.conf" -e "/ssl_certificate/s/^  #//"
sudo ln -s "/etc/nginx/sites-available/$MASTODON_DOMAIN.conf" "/etc/nginx/sites-enabled/$MASTODON_DOMAIN.conf"
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

# configure mastodon systemd services
sudo cp "$MASTODON_ROOT"/live/dist/mastodon-*.service /etc/systemd/system/

# start everything up!
sudo systemctl daemon-reload
sudo systemctl enable --now mastodon-web mastodon-sidekiq mastodon-streaming

# create admin account
sudo -u mastodon RAILS_ENV=production "$RBENV_ROOT/shims/ruby" "$MASTODON_ROOT/live/bin/tootctl" accounts create \
  "$MASTODON_ADMIN_USERNAME" \
  --email "$MASTODON_ADMIN_EMAIL" \
  --role Owner \
  --confirmed

# set cleanup tasks to run weekly
# https://docs.joinmastodon.org/admin/setup/#cleanup
(sudo crontab -l; echo -e "\n# Added by mastodon-installer @ $(date)
@weekly  mastodon  RAILS_ENV=production $RBENV_ROOT/shims/ruby $MASTODON_ROOT/live/bin/tootctl media remove
@weekly  mastodon  RAILS_ENV=production $RBENV_ROOT/shims/ruby $MASTODON_ROOT/live/bin/tootctl preview_cards remove
") | sudo crontab -

echo "🎉 All done!"
echo -e "\nSign in here as '$MASTODON_ADMIN_EMAIL' with the password above 👆:"
echo "https://$MASTODON_DOMAIN/auth/sign_in"
echo -e "\n...and consider working on these highly recommended next steps:"
echo "https://github.com/jakejarvis/mastodon-installer#whats-next"
