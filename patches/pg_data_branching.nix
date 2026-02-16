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
    rev = "main";
    sha256 = lib.fakeSha256;
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

  installPhase = ''
    mkdir -p $out/{lib,share/postgresql/extension}

    find target/release -name "pg_data_branching.so" -exec cp {} $out/lib/ \;
    cp pg_data_branching.control $out/share/postgresql/extension/
    cp pg_data_branching--*.sql $out/share/postgresql/extension/ 2>/dev/null || true

    patchelf --set-rpath "${btrfs-progs}/lib:${postgresql}/lib" $out/lib/pg_data_branching.so
  '';

  meta = with lib; {
    description = "postgres extension for database branching via btrfs and zfs snapshots";
    homepage = "https://github.com/mgrom/pg_data_branching";
    platforms = postgresql.meta.platforms;
    license = licenses.mit;
  };
}
