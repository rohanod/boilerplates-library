---
name: create-compose-template
description: Create or add a Docker Compose template in this repository. Use whenever a user asks for a new Compose workload, stack, service, app, or self-hosted tool template.
version: 1.0.0
---

# Create a Docker Compose Template

Build the smallest useful template that follows this repository's conventions.

## 1. Read the repository rules

Read `AGENTS.md` before making changes. Its upstream, naming, and commit rules are mandatory.

## 2. Check the original library first

Search `https://github.com/ChristianLempa/boilerplates-library` for the requested tool and common name variants.

- If it exists, clone or fetch the original repository into a temporary/cache location and copy only that template and its required files.
- If it does not exist, create the template from the project's official documentation.
- Never modify the original repository checkout.

## 3. Confirm the supported deployment

Use official application and container documentation to identify:

- the latest stable, versioned container image (never use a floating `latest` tag),
- required and optional ports,
- persistent paths,
- supported environment variables and secrets,
- health checks, dependencies, networks, and initialization requirements,
- architecture or upgrade limitations that materially affect users.

Prefer the application's simplest supported homelab deployment. Do not add a database, cache, sidecar, proxy, or abstraction unless the application requires it or the user asks for it.

## 4. Reuse the closest local pattern

Inspect existing templates before writing:

- `compose/r-changedetection/` for a simple single-service app,
- `compose/r-infisical/` for an app with supporting services, secrets, and `.env`,
- `compose/r-nginxproxymanager/` for multiple ports and multiple persistent paths.

Reuse their variable shapes and template syntax instead of inventing new conventions.

## 5. Create the template

Use this layout:

```text
compose/r-<name>/
├── template.json
└── files/
    ├── compose.yaml
    └── .env                 # only when generated secrets/config require it
```

Keep these values identical:

- directory: `compose/r-<name>`
- `slug`: `r-<name>`
- `metadata.name`: `r-<name>`

`template.json` must contain:

- `kind: "compose"`,
- a practical description, tags, icon, and `draft: false`,
- pinned `metadata.version.name`, `source_dep_name`, and `source_dep_version`,
- grouped variables with types, defaults, descriptions, and `needs` conditions.

The pinned image tag in `files/compose.yaml` must match the version metadata.

Use the repository delimiters:

- values: `<< variable >>`
- conditions/loops: `<% ... %>` / `<%- ... %>`
- comments: `<# ... #>`

## 6. Expose useful configuration

Represent application-supported choices in `template.json` when relevant:

- service/container name,
- timezone and restart policy,
- host ports,
- application URLs and settings,
- credentials and generated secrets,
- optional external dependencies,
- optional Traefik routing and TLS,
- persistent storage.

For persistent data, use the established `volume_mode` choices when they fit:

- `local`: Docker-managed named volumes,
- `mount`: host bind mounts under `volume_mount_path`,
- `nfs`: named volumes using `volume_nfs_server`, `volume_nfs_path`, and `volume_nfs_options`.

Only expose options the generated files actually use. Do not add speculative settings "for later."

## 7. Update the README

Add the template to the table in `README.md` and add a generation example:

```bash
boilerplates compose generate r-<name> --output ./<name>
```

## 8. Verify before reporting completion

At minimum:

1. Parse `template.json` as JSON.
2. Confirm the directory, `slug`, `metadata.name`, version metadata, and image tag agree.
3. Confirm every `<< variable >>` used by generated files is declared in `template.json`.
4. Generate the template into a temporary directory with `boilerplates compose generate` when the CLI is available.
5. Exercise each meaningful conditional branch that the template provides, such as:
   - direct ports and Traefik,
   - HTTP and TLS routing,
   - `local`, `mount`, and `nfs` storage,
   - bundled and external dependencies.
6. Run `docker compose -f <generated>/compose.yaml config` for each generated Compose file when Docker Compose is available.
7. Reject output containing unresolved `<<`, `<%`, or `<#` delimiters.
8. Run `git diff --check` and inspect the final diff for unrelated changes.

If a required tool is unavailable, run the remaining checks and state exactly what was skipped.

## 9. Stop at the implementation boundary

Report:

- whether the original library contained the tool,
- the official source used,
- the pinned version,
- files created or changed,
- verification performed and anything skipped.

Do not commit or push unless the user explicitly asks. Never add co-author trailers.
