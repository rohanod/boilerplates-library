Personal **Boilerplates** template library for homelab and self-hosted infrastructure.

Original collection: [ChristianLempa/boilerplates-library](https://github.com/ChristianLempa/boilerplates-library)

## Templates

| Kind | Template | Version | Description |
| --- | --- | --- | --- |
| `compose` | `r-bambuddy` | `0.2.4.9` | Print-farm management for Bambu Lab printers |
| `compose` | `r-changedetection` | `0.55.8` | Website change detection and notifications |
| `compose` | `r-cloudflared-web` | `2026.7.2` | Cloudflared tunnel client with a web management interface |
| `compose` | `r-infisical` | `v0.162.7` | Secrets management with PostgreSQL and Redis |
| `compose` | `r-karakeep` | `0.32.0` | Bookmark archiving, full-text search, and optional AI tagging |
| `compose` | `r-nginxproxymanager` | `2.15.1` | Reverse proxy UI with SSL certificates |
| `compose` | `r-spoolman` | `0.24.0` | Filament spool inventory and usage tracking |

## Use this library

Install the [Boilerplates CLI](https://github.com/christianlempa/boilerplates), then add this repo as a template library:

```bash
# Run this outside the managed library directory. Removing a library deletes its checkout.
cd ~

# Add this repository as a root-layout Git library.
boilerplates repo add rohan \
  --type git \
  --url https://github.com/rohanod/boilerplates-library.git \
  --branch main \
  --directory . \
  --enabled \
  --sync

# Refresh libraries later.
boilerplates repo update rohan

# List compose templates from this library
boilerplates compose list

# Generate a template (interactive)
boilerplates compose generate TEMPLATE

# Generate into a directory with overrides
boilerplates compose generate TEMPLATE --output ./out \
  --var service_name=TEMPLATE \
  --no-interactive
```

Examples:

```bash
boilerplates compose generate r-bambuddy --output ./bambuddy
boilerplates compose generate r-changedetection --output ./changedetection
boilerplates compose generate r-cloudflared-web --output ./cloudflared-web
boilerplates compose generate r-infisical --output ./infisical
boilerplates compose generate r-karakeep --output ./karakeep
boilerplates compose generate r-nginxproxymanager --output ./nginxproxymanager
boilerplates compose generate r-spoolman --output ./spoolman
```

## Update template versions

Detect the latest GitHub release and confirm before applying it:

```bash
node scripts/update-template-version.mjs r-karakeep
```

Or supply the newest version manually:

```bash
node scripts/update-template-version.mjs r-karakeep 0.33.0
```

## License

This repository is licensed under the [MIT License](./LICENSE).
