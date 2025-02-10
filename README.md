# supabase-branching

database branching for self-hosted supabase using [pg_data_branching](https://github.com/mgrom/pg_data_branching) and btrfs copy-on-write snapshots.

creates instant database branches regardless of size. no more waiting for `pg_dump`/`pg_restore` cycles on large databases.

works by injecting the pg_data_branching extension into the upstream [supabase/postgres](https://github.com/supabase/postgres) nix build at image build time. pg_data_branching uses btrfs snapshots under the hood, making `CREATE DATABASE ... WITH TEMPLATE` near-instant even on multi-GB databases.

## requirements

- linux host with btrfs support (`btrfs-progs`)
- docker + docker compose
- a btrfs-formatted partition or loopback device for postgres data

## quickstart

```bash
git clone https://github.com/mgrom/supabase-branching.git
cd supabase-branching
cp .env.example .env

# prepare btrfs volume (skip if you already have one)
sudo ./setup-btrfs.sh --loopback

# build custom postgres image with pg_data_branching
make build

# start
make up

# create a branch
./branch create staging
./branch list
./branch switch staging
```

## how it works

the build script (`build.sh`):

1. clones [supabase/postgres](https://github.com/supabase/postgres) upstream
2. copies `patches/pg_data_branching.nix` into the nix extension directory
3. patches `flake.nix` to include pg_data_branching in the build
4. patches `postgresql.conf` to add pg_data_branching to `shared_preload_libraries`
5. builds the docker image

the pg_data_branching extension ([mgrom/pg_data_branching](https://github.com/mgrom/pg_data_branching)) uses filesystem snapshots (btrfs + zfs) to make `CREATE DATABASE ... WITH TEMPLATE` near-instant regardless of database size.


## branch cli

```bash
./branch create <name> [--from <source>]   # branch from source db (default: main)
./branch list                               # list all branches
./branch delete <name>                      # drop a branch
./branch switch <name>                      # print connection string
./branch status                             # show databases with sizes
```

## configuration

see `.env.example`. key settings:

| variable | default | description |
|----------|---------|-------------|
| `POSTGRES_PASSWORD` | - | superuser password |
| `POSTGRES_DB` | `postgres` | main database |
| `BTRFS_MOUNT` | `/mnt/pgdata` | btrfs mount for pg data |
| `SUPABASE_POSTGRES_REF` | `develop` | upstream branch/tag to build from |

## limitations

- linux only (btrfs requirement)
- pg_data_branching is experimental / pre-alpha
- branches share the btrfs volume - deleting volume removes all branches
- no automatic branch-per-PR integration yet

## license

MIT
