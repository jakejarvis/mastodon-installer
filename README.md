# 🦣 Mastodon installer (unofficial)

> ⚠️ This is ***beyond experimental*** and may need some manual intervention from you. [Let me know](https://github.com/jakejarvis/mastodon-installer/issues) about any problems you run into!

![Escape the Space Karen](https://user-images.githubusercontent.com/1703673/202923190-95424152-3eb5-45ed-86e7-0ae0c89f917c.JPG)

Be your own [hall monitor](https://twitter.com/elonmusk/status/1594757734267764774) and host your own [Mastodon](https://joinmastodon.org/) server on the fediverse!

## Requirements

- Ubuntu 20.04 LTS (support for 22.04 is in the works!)
- A server or [VPS](https://github.com/joedicastro/vps-comparison) (in the cloud, on your Raspberry Pi, anywhere!) with ***at least*** 2 GB of memory
- A domain name (or subdomain) already pointing to this server's public IP address

## Usage

### Running the script

If you trust me (which you shouldn't, _please_ don't trust random people on the internet!) this will download and run the installer automatically:

```sh
# with curl
curl -fsSL https://github.com/jakejarvis/mastodon-installer/raw/HEAD/install.sh | bash

# alternatively, with wget
wget -q https://github.com/jakejarvis/mastodon-installer/raw/HEAD/install.sh -O- | bash
```

Or, clone this repository and make sure the installer is executable before running:

```sh
git clone https://github.com/jakejarvis/mastodon-installer.git && cd mastodon-installer
chmod +x install.sh
./install.sh
```

### What's next?

- [Close new registrations](https://discourse.joinmastodon.org/t/how-to-close-registrations/2629/2) if you intend for this to be a single-user server.
- Review the many [config options](https://docs.joinmastodon.org/admin/config/) located in `/home/mastodon/live/.env.production`
- Harden your server's security using:
  - [UFW](https://www.linode.com/docs/guides/configure-firewall-with-ufw/) or [iptables](https://docs.joinmastodon.org/admin/prerequisites/#install-a-firewall-and-only-allow-ssh-http-and-https-ports)
  - [Fail2ban](https://docs.joinmastodon.org/admin/prerequisites/#install-fail2ban-so-it-blocks-repeated-login-attempts)
- Configure an email provider:
  - [Mailgun](https://www.mailgun.com/products/send/smtp/free-smtp-service/) and [SendGrid](https://sendgrid.com/free/) have a free tier
  - ...but any regular SMTP server will work.
- [Offload media files to Amazon S3](https://docs.joinmastodon.org/admin/optional/object-storage-proxy/). They **will** eat a ton of disk space, even on a single-user server!
- Tune [Sidekiq & Puma](https://docs.joinmastodon.org/admin/scaling/#concurrency) for performance and consider using [pgBouncer](https://docs.joinmastodon.org/admin/scaling/#pgbouncer).
  - [Official scaling docs](https://docs.joinmastodon.org/admin/scaling/)
  - [Scaling Mastodon _down_](https://gist.github.com/nolanlawson/fc027de03a7cc0b674dcdc655eb5f2cb)
  - [PGTune](https://pgtune.leopard.in.ua/#/)

## Software installed

- Mastodon, of course
- Nginx
- PostgreSQL
- Redis
- Node + Yarn
- Ruby
- Certbot

## License

MIT
