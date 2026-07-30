---
name: create-compose-template
description: Create or add a Docker Compose template in this repository. Use whenever a user asks for a new Compose workload, stack, service, app, or self-hosted tool template.
version: 2.0.0
---

# Create a Docker Compose Template

Build the smallest useful template that follows this repository's Copier conventions.

## 1. Read the repository rules

Read `AGENTS.md` before making changes. Its upstream, naming, Copier, and commit rules are mandatory.

## 2. Check the original library first

Search `https://github.com/ChristianLempa/boilerplates-library` for the requested tool and common name variants.

- If it exists, clone or fetch the original repository into a temporary or cached location and copy only that template and its required files.
- If it does not exist, create the template from the project's official documentation.
- Never modify the original repository checkout.

## 3. Confirm the supported deployment

Use official application and container documentation to identify:

- the latest stable, versioned container image; never use a floating `latest` tag,
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
- `compose/r-nginxproxymanager/` for multiple ports and persistent paths.

Reuse existing root questions and payload syntax instead of inventing new conventions.

## 5. Create the template

Use this layout:

```text
compose/r-<name>/
├── questions.yml
└── files/
    ├── .copier-answers.yml
    ├── compose.yaml
    └── .env                 # only when needed
```

Add `r-<name>` to the root `template` choices and add a root `!include` for the new `questions.yml`. Never add a nested `copier.yml`.

Keep shared question names in root `copier.yml`. Put only unique questions in the fragment, and include `template == 'r-<name>'` in every `when` condition. Controller questions must appear before questions whose `when` or default references them.

Use the repository delimiters:

- values: `<< variable >>`
- conditions and loops: `<% ... %>` / `<%- ... %>`
- comments: `<# ... #>`

## 6. Expose useful configuration

Expose only application-supported choices used by the generated files. Reuse established questions for service names, restart policies, proxy integrations, ports, and storage.

For persistent data, use `volume_mode` when it fits:

- `local`: Docker-managed named volumes,
- `mount`: host bind mounts under `volume_mount_path`,
- `nfs`: named volumes using `volume_nfs_server`, `volume_nfs_path`, and `volume_nfs_options`.

User-supplied credentials use `type: str` and `secret: true`. For automatically generated credentials, add an explicit sentinel to `.env` and extend the idempotent copy task in root `copier.yml`; reuse the same sentinel everywhere the value must match. The task must use local tooling only and must not perform network or deployment side effects.

## 7. Update the README

Add the template to the table and add a Copier example:

```bash
copier copy --trust -d template=r-<name> gh:rohanod/boilerplates-library ./<name>
```

## 8. Keep versioning authoritative

Pinned image tags in `files/compose.yaml` are the application-version source of truth. Do not recreate per-template version metadata; Renovate updates the image references directly.

Copier versions this repository as a whole, not each stack independently. Release tags must be PEP 440-compatible, such as `v1.0.0`, so generated projects can resolve and record a stable `_commit` in `.copier-answers.yml`. All eight selectors share that release stream. Do not create or push a repository tag unless the user explicitly asks.

When changing an image tag manually, verify it against the application's official release source and run the full template check. An image update alone does not require a Copier migration; reserve `_migrations` for destination transformations that normal Copier updates cannot express.

## 9. Verify before reporting completion

Never start containers or execute generated workloads. `docker compose config` is allowed because it only parses configuration.

At minimum:

1. Run `scripts/check-copier-templates.sh`.
2. Confirm every payload variable is declared once in root `copier.yml` or the template fragment.
3. Exercise meaningful conditional branches such as direct ports, proxy routing, TLS, storage modes, and bundled versus external dependencies.
4. Reject unresolved `<<`, `<%`, `<#`, or `__COPIER_` markers.
5. Run `docker compose config --quiet` against generated Compose files.
6. Run `git diff --check` and inspect the final diff for unrelated changes.

If a required tool is unavailable, run the remaining checks and state exactly what was skipped.

## 10. Stop at the implementation boundary

Report the upstream and official sources used, pinned image version, files changed, verification performed, and anything skipped. Do not commit or push unless explicitly asked. Never add co-author trailers.
