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
    echo "this tool expects the nix-based build system"
    exit 1
fi

# inject pg_data_branching nix derivation
echo "injecting pg_data_branching extension..."
cp "$SCRIPT_DIR/patches/pg_data_branching.nix" nix/ext/pg_data_branching.nix

if ! grep -q "pg_data_branching" flake.nix; then
    if grep -q '\.\/nix\/ext\/supautils\.nix' flake.nix; then
        sed -i '/\.\/nix\/ext\/supautils\.nix/a\          ./nix/ext/pg_data_branching.nix' flake.nix
    else
        echo "error: expected anchor './nix/ext/supautils.nix' not found in flake.nix"
        echo "the upstream layout may have changed; patch flake.nix manually"
        exit 1
    fi
    grep -q "pg_data_branching" flake.nix || { echo "error: flake.nix patch failed"; exit 1; }
    echo "  patched flake.nix"
else
    echo "  flake.nix already patched"
fi

CONF="ansible/files/postgresql_config/postgresql.conf.j2"
if [ -f "$CONF" ] && ! grep -q "pg_data_branching" "$CONF"; then
    sed -i "s/shared_preload_libraries = '\(.*\)'/shared_preload_libraries = '\1, pg_data_branching'/" "$CONF"
    if ! grep -q "pg_data_branching" "$CONF"; then
        echo "error: failed to patch shared_preload_libraries in $CONF"
        echo "format may have changed; add pg_data_branching manually"
        exit 1
    fi
    echo "  patched shared_preload_libraries"
elif [ ! -f "$CONF" ]; then
    echo "error: $CONF not found; cannot configure shared_preload_libraries"
    echo "add 'pg_data_branching' to shared_preload_libraries manually and rebuild"
    exit 1
fi

# build docker image
if [ -f "Dockerfile" ]; then
    docker build -t "$IMAGE" .
elif [ -f "docker/Dockerfile" ]; then
    docker build -t "$IMAGE" -f docker/Dockerfile .
else
    echo "error: no Dockerfile found in supabase/postgres"
    exit 1
fi

echo ""
echo "built: $IMAGE"
echo "run 'make up' to start"
