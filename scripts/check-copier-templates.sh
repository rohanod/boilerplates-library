#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/copier-templates.XXXXXX")"
source_copy="$temporary/source"
trap '/bin/rm -rf "$temporary"' EXIT

mkdir -p "$source_copy"
cp -R "$root/." "$source_copy"
/bin/rm -rf "$source_copy/.git"

templates=(
  bambuddy
  changedetection
  cloudflared-web
  karakeep
  nginxproxymanager
  spoolman
  tinyauth
)

question_duplicates="$(
  {
    rg --no-filename '^[a-z][a-z0-9_]*:$' "$root/copier.yml"
    rg --no-filename '^[a-z][a-z0-9_]*:$' "$root"/boilerplates/*/{questions,options}.yml
  } | sort | uniq -d
)"
if [[ -n "$question_duplicates" ]]; then
  printf 'Duplicate Copier question names:\n%s\n' "$question_duplicates" >&2
  exit 1
fi

secret_answer_pattern='^(auth_users|crawler_http_proxy|crawler_https_proxy|database_connection_uri|database_password|database_url|email_password|github_client_secret|gitlab_client_secret|google_client_secret|home_assistant_token|http_proxy|https_proxy|initial_admin_password|ldap_bind_password|npm_database_password|oauth_client_secret|oidc_client_secret|openai_api_key|redis_url|s3_access_key_id|s3_secret_access_key|smtp_password):'

validate_output() {
  local name="$1"
  local output="$2"

  test -s "$output/compose.yaml"
  test -s "$output/.copier-answers.yml"

  if rg -q '__COPIER_|<<|<%|<#' "$output" --hidden; then
    printf 'Unresolved template marker in %s\n' "$name" >&2
    exit 1
  fi

  if rg -q "$secret_answer_pattern" "$output/.copier-answers.yml"; then
    printf 'Secret answer recorded for %s\n' "$name" >&2
    exit 1
  fi

  if [[ -f "$output/.env" ]]; then
    grep -qxF .env "$output/.gitignore"
  fi

  docker compose \
    --project-directory "$output" \
    -f "$output/compose.yaml" \
    config --quiet
}

render() {
  local name="$1"
  shift
  local output="$temporary/$name"

  copier copy --quiet --trust --defaults "$@" "$source_copy" "$output" >/dev/null
  validate_output "$name" "$output"
}

for template in "${templates[@]}"; do
  args=(-d "template=$template")
  if [[ "$template" == tinyauth ]]; then
    args+=(-d 'auth_users=admin:$2a$10$abcdefghijklmnopqrstuv')
  fi

  render "$template" "${args[@]}"
  grep -q "^template: $template$" "$temporary/$template/.copier-answers.yml"
done

# Generated secrets and ignored environment files.
grep -Eq "^BASIC_AUTH_PASS='[^']+'$" "$temporary/cloudflared-web/.env"
grep -Eq "^NEXTAUTH_SECRET='[^']+'$" "$temporary/karakeep/.env"
grep -Eq "^MEILI_MASTER_KEY='[^']+'$" "$temporary/karakeep/.env"

# Default optional gating and explicit destination-relative data path.
grep -q '^configure_optional: false$' "$temporary/bambuddy/.copier-answers.yml"
! grep -q '^optional_groups:' "$temporary/bambuddy/.copier-answers.yml"
grep -q '../data/bambuddy/data:/app/data' "$temporary/bambuddy/compose.yaml"
! grep -q 'npm-proxy' "$temporary/bambuddy/compose.yaml"
! grep -q 'browser-sockpuppet-chrome' "$temporary/changedetection/compose.yaml"

# NPM proxy integration for every supported application.
render bambuddy-proxy \
  -d template=bambuddy \
  -d network_mode=bridge \
  -d configure_optional=true \
  -d 'optional_groups=[runtime,npm_proxy]' \
  -d npm_proxy_network=shared-proxy \
  -d virtual_printer_enabled=true
grep -q 'bambuddy-web' "$temporary/bambuddy-proxy/compose.yaml"
grep -q 'name: shared-proxy' "$temporary/bambuddy-proxy/compose.yaml"
! grep -q '"8000:8000"' "$temporary/bambuddy-proxy/compose.yaml"
grep -q '"3000:3000"' "$temporary/bambuddy-proxy/compose.yaml"
grep -q '"50000-50029:50000-50029"' "$temporary/bambuddy-proxy/compose.yaml"

render bambuddy-libraries \
  -d template=bambuddy \
  -d configure_optional=true \
  -d 'optional_groups=[libraries,certificates_backups]' \
  -d 'external_libraries=[{"host_path":"/mnt/library","container_path":"/external/library"}]' \
  -d private_ca_enabled=true \
  -d private_ca_host_path=/etc/ssl/local-certs \
  -d backup_host_path=/mnt/backups/bambuddy
grep -q 'BAMBUDDY_EXTERNAL_ROOTS=/external/library' "$temporary/bambuddy-libraries/compose.yaml"
grep -q '/mnt/library:/external/library:ro' "$temporary/bambuddy-libraries/compose.yaml"
grep -q '/etc/ssl/local-certs:/usr/local/share/ca-certificates:ro' "$temporary/bambuddy-libraries/compose.yaml"
grep -q '/mnt/backups/bambuddy:/app/data/backups' "$temporary/bambuddy-libraries/compose.yaml"

proxy_apps=(
  'changedetection changedetection-web 5000'
  'karakeep karakeep-web 3000'
  'spoolman spoolman-web 7912'
  'tinyauth tinyauth-web 3000'
)

for definition in "${proxy_apps[@]}"; do
  read -r template alias direct_port <<<"$definition"
  args=(
    -d "template=$template"
    -d configure_optional=true
    -d 'optional_groups=[npm_proxy]'
    -d npm_proxy_network=shared-proxy
  )
  if [[ "$template" == tinyauth ]]; then
    args+=(-d 'auth_users=admin:$2a$10$abcdefghijklmnopqrstuv')
  fi

  render "$template-proxy" "${args[@]}"
  grep -q "$alias" "$temporary/$template-proxy/compose.yaml"
  grep -q 'name: shared-proxy' "$temporary/$template-proxy/compose.yaml"
  ! grep -q "\"$direct_port:" "$temporary/$template-proxy/compose.yaml"
done

render npm-proxy \
  -d template=nginxproxymanager \
  -d configure_optional=true \
  -d 'optional_groups=[npm_proxy]' \
  -d npm_proxy_network=shared-proxy
grep -q 'name: shared-proxy' "$temporary/npm-proxy/compose.yaml"
grep -q '"80:80"' "$temporary/npm-proxy/compose.yaml"
grep -q '"443:443"' "$temporary/npm-proxy/compose.yaml"
grep -q '"81:81"' "$temporary/npm-proxy/compose.yaml"

# Cloudflared Web cannot select the NPM-only group.
if copier copy --quiet --trust --defaults \
  -d template=cloudflared-web \
  -d configure_optional=true \
  -d 'optional_groups=[npm_proxy]' \
  "$source_copy" "$temporary/cloudflared-invalid" >/dev/null 2>&1; then
  printf 'Cloudflared Web accepted an unsupported NPM group.\n' >&2
  exit 1
fi

# Representative official options and upstream correctness fixes.
render changedetection-browser \
  -d template=changedetection \
  -d configure_optional=true \
  -d 'optional_groups=[browser,outbound_proxy,fetch]' \
  -d browser_mode=sidecar \
  -d http_proxy=http://proxy.example.com:3128
grep -q 'docker.io/dgtlmoon/sockpuppetbrowser:latest' "$temporary/changedetection-browser/compose.yaml"
grep -q 'PLAYWRIGHT_DRIVER_URL=ws://browser-sockpuppet-chrome:3000' "$temporary/changedetection-browser/compose.yaml"
grep -q "HTTP_PROXY='http://proxy.example.com:3128'" "$temporary/changedetection-browser/.env"

render karakeep-ollama \
  -d template=karakeep \
  -d configure_optional=true \
  -d 'optional_groups=[ai]' \
  -d ai_provider=ollama
grep -q 'ghcr.io/karakeep-app/karakeep-chrome:release' "$temporary/karakeep-ollama/compose.yaml"
! rg -q 'gcr.io/zenika-hub/alpine-chrome' "$root/boilerplates/karakeep"

render npm-mysql \
  -d template=nginxproxymanager \
  -d configure_optional=true \
  -d 'optional_groups=[database]' \
  -d npm_database_type=mysql \
  -d npm_database_host=database \
  -d npm_database_password=test-password
grep -q "DB_MYSQL_PORT='3306'" "$temporary/npm-mysql/.env"

render spoolman-postgres \
  -d template=spoolman \
  -d configure_optional=true \
  -d 'optional_groups=[database,catalog]' \
  -d database_type=postgres \
  -d database_host=database \
  -d database_password=test-password
grep -q 'SPOOLMAN_DB_TYPE=postgres' "$temporary/spoolman-postgres/compose.yaml"
grep -q 'SPOOLMAN_DB_PORT=5432' "$temporary/spoolman-postgres/compose.yaml"
grep -q 'EXTERNAL_DB_NAME=SpoolmanDB' "$temporary/spoolman-postgres/compose.yaml"

render spoolman-mysql \
  -d template=spoolman \
  -d configure_optional=true \
  -d 'optional_groups=[database]' \
  -d database_type=mysql \
  -d database_host=database \
  -d database_password=test-password
grep -q 'SPOOLMAN_DB_PORT=3306' "$temporary/spoolman-mysql/compose.yaml"

render changedetection-nfs \
  -d template=changedetection \
  -d volume_mode=nfs

render tinyauth-policy \
  -d template=tinyauth \
  -d 'auth_users=admin:$2a$10$abcdefghijklmnopqrstuv' \
  -d configure_optional=true \
  -d 'optional_groups=[session_access,ui,privacy_logging]'
! grep -q '172.17.0.0/16' "$temporary/tinyauth-policy/.env"
grep -q "TINYAUTH_AUTH_SESSIONEXPIRY='86400'" "$temporary/tinyauth-policy/.env"

if copier copy --quiet --trust --defaults \
  -d template=tinyauth \
  -d 'auth_sources=[]' \
  "$source_copy" "$temporary/tinyauth-invalid" >/dev/null 2>&1; then
  printf 'TinyAuth accepted an empty authentication-source selection.\n' >&2
  exit 1
fi

legacy_proxy='trae''fik'
if rg -ni "$legacy_proxy" "$root" --glob '!.git/**'; then
  printf 'Legacy proxy integration remains in the repository.\n' >&2
  exit 1
fi

git -C "$root" diff --check
printf 'Validated %s defaults and grouped conditional variants.\n' "${#templates[@]}"
