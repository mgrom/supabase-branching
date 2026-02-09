#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then set -a; source "$SCRIPT_DIR/.env"; set +a; fi

REPO="https://github.com/supabase/postgres.git"
REF="${SUPABASE_POSTGRES_REF:-develop}"
IMAGE="${IMAGE_NAME:-supabase-postgres-branching}:${IMAGE_TAG:-latest}"
BUILD_DIR="$SCRIPT_DIR/.build"

echo "building $IMAGE from supabase/postgres@$REF"

# clone or update
if [ -d "$BUILD_DIR/supabase_postgres" ]; then
    echo "updating existing checkout..."
    cd "$BUILD_DIR/supabase_postgres"
    git fetch origin && git checkout "$REF"
    git pull origin "$REF" 2>/dev/null || true
    cd "$SCRIPT_DIR"
else
    echo "cloning supabase/postgres..."
    mkdir -p "$BUILD_DIR"
    git clone --depth 1 --branch "$REF" "$REPO" "$BUILD_DIR/supabase_postgres"
fi

cd "$BUILD_DIR/supabase_postgres"

if [ ! -f "flake.nix" ]; then
    echo "error: no flake.nix in supabase/postgres@$REF"
    echo "this tool expects the nix-based build. check that REF is correct."
    exit 1
fi

# inject pg_branch nix derivation
echo "injecting pg_branch extension..."
cp "$SCRIPT_DIR/patches/pg_branch.nix" nix/ext/pg_branch.nix

if ! grep -q "pg_branch" flake.nix; then
    sed -i '/\.\/nix\/ext\/supautils\.nix/a\          ./nix/ext/pg_branch.nix' flake.nix
    echo "  patched flake.nix"
else
    echo "  flake.nix already patched"
fi

CONF="ansible/files/postgresql_config/postgresql.conf.j2"
if [ -f "$CONF" ] && ! grep -q "pg_branch" "$CONF"; then
    sed -i "s/shared_preload_libraries = '\(.*\)'/shared_preload_libraries = '\1, pg_branch'/" "$CONF"
    echo "  patched shared_preload_libraries"
elif [ ! -f "$CONF" ]; then
    echo "  warning: $CONF not found, shared_preload_libraries not patched"
    echo "  you may need to configure pg_branch manually"
fi

# find and run dockerfile
if [ -f "Dockerfile" ]; then
    docker build -t "$IMAGE" .
elif [ -f "docker/Dockerfile" ]; then
    docker build -t "$IMAGE" -f docker/Dockerfile .
else
    echo "error: no Dockerfile found in supabase/postgres"
    echo "repo structure may have changed"
    exit 1
fi

echo ""
echo "built: $IMAGE"
echo "run 'make up' to start"
