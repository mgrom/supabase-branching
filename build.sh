#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a; source "$SCRIPT_DIR/.env"; set +a
fi

REPO="https://github.com/supabase/postgres.git"
REF="${SUPABASE_POSTGRES_REF:-develop}"
IMAGE="${IMAGE_NAME:-supabase-postgres-branching}:${IMAGE_TAG:-latest}"
BUILD_DIR="$SCRIPT_DIR/.build"

echo "building $IMAGE from supabase/postgres@$REF"

# clone or update
if [ -d "$BUILD_DIR/supabase_postgres" ]; then
    cd "$BUILD_DIR/supabase_postgres"
    git fetch origin && git checkout "$REF"
    git pull origin "$REF" 2>/dev/null || true
    cd "$SCRIPT_DIR"
else
    mkdir -p "$BUILD_DIR"
    git clone --depth 1 --branch "$REF" "$REPO" "$BUILD_DIR/supabase_postgres"
fi

# inject pg_branch
echo "injecting pg_branch extension..."
cp "$SCRIPT_DIR/patches/pg_branch.nix" "$BUILD_DIR/supabase_postgres/nix/ext/pg_branch.nix"

cd "$BUILD_DIR/supabase_postgres"

# patch flake.nix
if ! grep -q "pg_branch" flake.nix; then
    sed -i '/\.\/nix\/ext\/supautils\.nix/a\          ./nix/ext/pg_branch.nix' flake.nix
fi

# patch shared_preload_libraries
CONF="ansible/files/postgresql_config/postgresql.conf.j2"
if [ -f "$CONF" ] && ! grep -q "pg_branch" "$CONF"; then
    sed -i "s/shared_preload_libraries = '\(.*\)'/shared_preload_libraries = '\1, pg_branch'/" "$CONF"
fi

docker build -t "$IMAGE" .

echo ""
echo "built: $IMAGE"
echo "run 'make up' to start"
