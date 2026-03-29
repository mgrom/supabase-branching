{ lib, stdenv, fetchFromGitHub, postgresql, btrfs-progs, patchelf, rustPlatform, libbtrfsutil, pkg-config, cargo-pgrx }:

let
  pgrxVersion = "0.17.0";
in
rustPlatform.buildRustPackage rec {
  pname = "pg_data_branching";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "mgrom";
    repo = "pg_data_branching";
    # pin to a specific commit for reproducible builds
    rev = "main";
    hash = "";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [ pkg-config patchelf cargo-pgrx ];
  buildInputs = [ postgresql btrfs-progs libbtrfsutil ];

  LIBCLANG_PATH = "${stdenv.cc.cc.lib}/lib";
  PG_CONFIG = "${postgresql}/bin/pg_config";
  PGRX_HOME = "/tmp/pgrx";

  preBuild = ''
    mkdir -p $PGRX_HOME
    cargo pgrx init --pg${lib.versions.major postgresql.version} ${postgresql}/bin/pg_config
  '';

  postBuild = ''
    cargo pgrx schema --pg-config ${PG_CONFIG} -o pg_data_branching--${version}.sql
  '';

  installPhase = ''
    mkdir -p $out/{lib,share/postgresql/extension}

    so=$(find target/release -maxdepth 1 -name "libpg_data_branching.so" | head -1)
    [ -z "$so" ] && { echo "error: libpg_data_branching.so not found"; exit 1; }
    cp "$so" $out/lib/pg_data_branching.so

    sed "s/@CARGO_VERSION@/${version}/" pg_data_branching.control \
      > $out/share/postgresql/extension/pg_data_branching.control
    cp pg_data_branching--${version}.sql $out/share/postgresql/extension/

    patchelf --set-rpath "${btrfs-progs}/lib:${postgresql}/lib" $out/lib/pg_data_branching.so
  '';

  meta = with lib; {
    description = "postgres extension for database branching via btrfs and zfs snapshots";
    homepage = "https://github.com/mgrom/pg_data_branching";
    platforms = postgresql.meta.platforms;
    license = licenses.mit;
  };
}
