# IARTNET Reverse Proxy

Nginx reverse proxy with TLS (Certbot) for the IARTNET stack.

## Role in suite

Routes public hostnames to:
- Frontend (Nuxt)
- Backoffice CMS (Laravel)
- Ingestion API (Laravel)
- IIIF Image (Cantaloupe via ingestion stack)

## Prerequisites

- Docker / Docker Compose
- External Docker networks to frontend, CMS, ingestion stacks

## Configuration

1. Copy environment templates and edit hostnames for your deployment:

```bash
cp env/proxy.stg.env.example env/proxy.stg.env    # staging
cp env/proxy.prod.env.example env/proxy.prod.env  # production
```

2. Deploy with the matching compose file:

- STG: `env/proxy.stg.env` + `docker-compose.stg.yml`
- PROD: `env/proxy.prod.env` + `docker-compose.prod.yml`

Tracked templates: `env/*.env.example` only — local `env/proxy.*.env` files are gitignored.

See `CERTBOT_SSL_RUNBOOK.md` for TLS operations.

## Deploy

```bash
./scripts/deploy-proxy.sh stg   # or prod
```

## Suite documentation

See the `iartnet-suite` repository in this workspace for cross-component architecture.

## License

GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later).

Copyright (c) 2026 Accademia di Brera / GPA Management Services. See [LICENSE](LICENSE).
