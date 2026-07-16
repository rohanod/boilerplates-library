![Welcome](./.assets/library-banner.jpg)

Personal **Boilerplates** template library for homelab and self-hosted infrastructure.

Original collection: [ChristianLempa/boilerplates-library](https://github.com/ChristianLempa/boilerplates-library)

## Templates

| Kind | Template | Version | Description |
| --- | --- | --- | --- |
| `compose` | `changedetection` | `0.55.8` | Website change detection and notifications |
| `compose` | `infisical` | `v0.162.7` | Secrets management with PostgreSQL and Redis |

## Use this library

Install the [Boilerplates CLI](https://github.com/christianlempa/boilerplates), then add this repo as a template library:

```bash
# Add this library (replace NAME if you want a different local library id)
boilerplates repo add NAME https://github.com/rohanod/boilerplates-library \
  --branch main

# Refresh libraries
boilerplates repo update

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
boilerplates compose generate changedetection --output ./changedetection
boilerplates compose generate infisical --output ./infisical
```

## License

This repository is licensed under the [MIT License](./LICENSE).
