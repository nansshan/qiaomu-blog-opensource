#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_PATH="$(bash "${SCRIPT_DIR}/cf-config.sh")"

cd "${REPO_ROOT}"

echo "==> using wrangler config: ${CONFIG_PATH}"
bash "${SCRIPT_DIR}/cf-validate-config.sh" "${CONFIG_PATH}"

rm -rf .next .open-next
npx opennextjs-cloudflare build

# Skip schema/seed by default to keep redeploys idempotent.
# Set APPLY_D1_SCHEMA=1 to force apply schema.sql and seed-template.sql.
if [[ "${APPLY_D1_SCHEMA:-0}" == "1" ]]; then
  echo "==> applying D1 schema (forced via APPLY_D1_SCHEMA=1)"
  npx wrangler d1 execute DB \
    --remote \
    --file="${REPO_ROOT}/db/schema.sql" \
    -c "${CONFIG_PATH}" || echo "==> schema apply failed (likely already initialized), continuing"

  if [[ -f "${REPO_ROOT}/db/seed-template.sql" ]]; then
    echo "==> applying template defaults"
    npx wrangler d1 execute DB \
      --remote \
      --file="${REPO_ROOT}/db/seed-template.sql" \
      -c "${CONFIG_PATH}" || echo "==> seed apply failed, continuing"
  fi
else
  echo "==> skipping D1 schema (set APPLY_D1_SCHEMA=1 to force apply)"
fi

npx opennextjs-cloudflare deploy -c "${CONFIG_PATH}"
