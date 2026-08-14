#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/copier-templates.XXXXXX")"
trap '/bin/rm -rf "$temporary"' EXIT

templates=(
  bambuddy
  changedetection
  cloudflared-web
  infisical
  karakeep
  nginxproxymanager
  spoolman
  tinyauth
)

grep -q 'Attach Nginx Proxy Manager to the existing external npm-proxy network' "$root/copier.yml"
! grep -q 'Attach BamBuddy to the existing external npm-proxy network' "$root/copier.yml"

for template in "${templates[@]}"; do
  output="$temporary/$template"
  copier copy --quiet --trust --defaults --vcs-ref=HEAD \
    -d "template=$template" \
    "$root" \
    "$output" >/dev/null

  test -s "$output/compose.yaml"
  test -s "$output/.copier-answers.yml"
  grep -q "^template: $template$" "$output/.copier-answers.yml"

  if rg -q '__COPIER_|<<|<%|<#' "$output" --hidden; then
    printf 'Unresolved template marker in %s\n' "$template" >&2
    exit 1
  fi

  if rg -q '^(basic_auth_password|database_password|database_connection_uri|database_url|email_password|home_assistant_token|infisical_auth_secret|infisical_encryption_key|meili_master_key|nextauth_secret|openai_api_key|redis_password|redis_url|auth_users):' "$output/.copier-answers.yml"; then
    printf 'Secret answer recorded for %s\n' "$template" >&2
    exit 1
  fi

  case "$template" in
    cloudflared-web)
      grep -Eq "^BASIC_AUTH_PASS='[^']+'$" "$output/.env"
      ;;
    infisical)
      grep -Eq "^ENCRYPTION_KEY='[^']+'$" "$output/.env"
      grep -Eq "^AUTH_SECRET='[^']+'$" "$output/.env"
      grep -Eq "^POSTGRES_PASSWORD='[^']+'$" "$output/.env"
      grep -Eq "^REDIS_PASSWORD='[^']+'$" "$output/.env"
      ;;
    karakeep)
      grep -Eq "^NEXTAUTH_SECRET='[^']+'$" "$output/.env"
      grep -Eq "^MEILI_MASTER_KEY='[^']+'$" "$output/.env"
      ;;
  esac

  if [[ -f "$output/.env" ]]; then
    grep -qxF .env "$output/.gitignore"
  fi

  docker compose \
    --project-directory "$output" \
    -f "$output/compose.yaml" \
    config --quiet

done

validate_variant() {
  local name="$1"
  shift
  local output="$temporary/$name"

  copier copy --quiet --trust --defaults --vcs-ref=HEAD "$@" "$root" "$output" >/dev/null
  ! rg -q '__COPIER_|<<|<%|<#' "$output" --hidden
  docker compose --project-directory "$output" -f "$output/compose.yaml" config --quiet
}

validate_variant changedetection-traefik-nfs \
  -d template=changedetection \
  -d traefik_enabled=true \
  -d traefik_tls_enabled=true \
  -d volume_mode=nfs

validate_variant bambuddy-bridge \
  -d template=bambuddy \
  -d network_mode=bridge \
  -d npm_proxy_enabled=true \
  -d virtual_printer_enabled=true

validate_variant infisical-external \
  -d template=infisical \
  -d database_external=true \
  -d database_connection_uri=postgresql://user:password@database:5432/infisical \
  -d redis_external=true \
  -d redis_url=redis://:password@redis:6379 \
  -d email_enabled=true \
  -d email_username=user@example.com \
  -d email_password=test-password

validate_variant karakeep-ollama \
  -d template=karakeep \
  -d ai_provider=ollama

validate_variant spoolman-postgresql \
  -d template=spoolman \
  -d database_type=postgresql \
  -d database_host=database \
  -d database_password=test-password

validate_variant changedetection-mount \
  -d template=changedetection \
  -d volume_mode=mount

grep -q '../data/changedetection/datastore:/datastore' "$temporary/changedetection-mount/compose.yaml"

git -C "$root" diff --check
printf 'Validated %s default templates and 6 conditional variants.\n' "${#templates[@]}"
