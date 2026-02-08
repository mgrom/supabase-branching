#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/supabase/postgres.git"
IMAGE="supabase-postgres-branching:latest"

echo "building $IMAGE"

mkdir -p .build
git clone --depth 1 "$REPO" .build/supabase_postgres

cd .build/supabase_postgres

# TODO: inject pg_branch extension
# TODO: patch flake.nix
# TODO: patch postgresql.conf
echo "WARNING: pg_branch injection not implemented yet"

docker build -t "$IMAGE" .
echo "built: $IMAGE"
