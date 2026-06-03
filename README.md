# Odoo Enterprise Docker Template

This repository is a deployment template for running Odoo Enterprise with Docker Compose, Traefik, PostgreSQL, and `odoo-mailer`.

## Stack

- **Odoo Enterprise** runs from the official `odoo:19.0` Docker image.
- **Enterprise addons** are mounted from `./addons` into `/mnt/extra-addons`.
- **Custom addons** are mounted from `./custom-addons` into `/mnt/custom-addons`.
- **PostgreSQL 15** stores the Odoo database.
- **Traefik v3** terminates HTTPS, redirects HTTP to HTTPS, and routes traffic to Odoo.
- **odoo-mailer** receives inbound email on SMTP port `25` and forwards messages to Odoo.

## Repository Layout

```text
.
├── docker-compose.yml
├── traefik.yml
├── dynamic/
│   ├── dynamic_routes.yml
│   └── middlewares.yml
├── config/
│   └── odoo.conf
├── init-enterprise-addons.sh
├── acme.json        # ignored: Let's encrypt certs
├── addons/          # ignored: Odoo Enterprise checkout
└── custom-addons/   # ignored: client/project addons
```

`addons/`, `custom-addons/`, `.env`, and `acme.json` are ignored because they contain cloned code, project-specific code, secrets, or generated TLS state.

## Requirements

- Docker and Docker Compose.
- Access to the private Odoo Enterprise GitHub repository.
- A domain pointing to the server.
- Ports `80`, `443`, and optionally `25` open on the host.

## Initial Setup

Create or update `.env`:

```env
POSTGRES_DB=postgres
POSTGRES_USER=odoo
POSTGRES_PASSWORD=change-me
HOST=db
ODOO_DOMAIN=odoo.example.com
```

Clone the Odoo Enterprise addons:

```sh
./init-enterprise-addons.sh
```

The script defaults to:

- branch: `19.0`
- repository: `git@github.com:odoo/enterprise.git`
- target directory: `addons`

You can override these values:

```sh
ODOO_VERSION=19.0 \
ENTERPRISE_REPO=https://github.com/odoo/enterprise.git \
TARGET_DIR=addons \
./init-enterprise-addons.sh
```

Create the ACME storage file before starting Traefik:

```sh
touch acme.json
chmod 600 acme.json
```

### Critical

Allow odoo user to edit config/odoo.conf (for master password)

```sh
sudo chown 100:101 ./config/odoo.conf
sudo chmod 664 ./config/odoo.conf
```

Start the stack:

```sh
docker compose up -d
```

## Traefik

Traefik is configured in `traefik.yml` and `dynamic/`.

The static configuration:

- listens on port `80` through the `web` entrypoint;
- redirects HTTP traffic to HTTPS;
- listens on port `443` through the `websecure` entrypoint;
- uses Let's Encrypt with the HTTP challenge;
- stores certificates in `acme.json`;
- loads routers, services, and middlewares from `dynamic/`.

The dynamic route file maps the configured Odoo domain to:

- `http://web:8069` for regular Odoo HTTP traffic;
- `http://web:8072` for websocket traffic under `/websocket`.

Set `ODOO_DOMAIN` in `.env` when changing the public domain:

```env
ODOO_DOMAIN=odoo.example.com
```

The dynamic Traefik configuration reads it through the file provider template:

```yaml
rule: 'Host(`{{ env "ODOO_DOMAIN" }}`)'
```

Traefik supports this templating in dynamic file-provider configuration files. Do not use this syntax in the main static `traefik.yml` file.

Update the Let's Encrypt email in `traefik.yml`:

```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@example.com
```

The included middlewares add security headers and a basic rate limit.

## Odoo Enterprise

Odoo uses `config/odoo.conf`.

The configured addons path is:

```ini
addons_path = /mnt/extra-addons,/mnt/custom-addons
```

Those paths correspond to these Docker mounts:

```yaml
./addons:/mnt/extra-addons
./custom-addons:/mnt/custom-addons
```

After cloning Enterprise addons, place project-specific modules in `custom-addons/`.

To view logs:

```sh
docker compose logs -f web
```

To restart Odoo after changing addons or config:

```sh
docker compose restart web
```

## odoo-mailer

`odoo-mailer` is included as an SMTP bridge for inbound email. It listens on host port `25` and forwards incoming messages to the Odoo container through the internal Docker network.

The relevant environment variables are configured in `docker-compose.yml`:

- `DOMAIN`: mail domain handled by the SMTP service.
- `ODOO_DB`: target Odoo database.
- `ODOO_USERID`: Odoo user used by the mailer.
- `ODOO_PASSWORD`: Odoo API key or password.
- `ODOO_HOST`: internal Docker service name, usually `web`.
- `ODOO_PORT`: Odoo HTTP port, usually `8069`.
- `ODOO_PROTO`: internal protocol, usually `http`.

For production, move credentials into `.env` or Docker secrets and reference them from `docker-compose.yml`.

## Common Commands

```sh
docker compose ps
docker compose logs -f traefik
docker compose logs -f odoo-mailer
docker compose down
docker compose pull
docker compose up -d
```
