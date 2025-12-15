#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:-angular-k8s-demo:local}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v pnpm >/dev/null 2>&1; then
  echo "pnpm not found. Install it first (or enable corepack)." >&2
  exit 1
fi

echo "[1/4] Build Angular -> dist/"
pnpm run build -- --configuration production

echo "[2/4] Verify dist exists"
test -f dist/angular-k8s-demo/index.html

echo "[3/4] Build Docker image: ${IMAGE_TAG}"
docker build -t "${IMAGE_TAG}" .

echo "[4/4] Build Docker image: ${IMAGE_TAG}"
docker build -t "${IMAGE_TAG}" .

echo "Done."
echo "Run: docker run --rm -p 8080:80 ${IMAGE_TAG}"
