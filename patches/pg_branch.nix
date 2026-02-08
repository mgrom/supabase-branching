{ lib, stdenv, fetchFromGitHub, postgresql, btrfs-progs, patchelf }:

stdenv.mkDerivation rec {
  pname = "pg_branch";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "boltpl81";
    repo = "pg_branch";
    rev = "master";
    sha256 = "1768q1ra8m121q24kg7garrafmwfy71idgjpnqzinaiq0f1as06r";
  };

  nativeBuildInputs = [ patchelf ];
  buildInputs = [ postgresql btrfs-progs ];
  propagatedBuildInputs = [ btrfs-progs ];

  installPhase = ''
    mkdir -p $out/{lib,share/postgresql/extension}

    BTRFS_LIB=$(find ${btrfs-progs}/lib -name "libbtrfsutil.so.1*" | head -n1)
    if [ -z "$BTRFS_LIB" ]; then
      echo "libbtrfsutil.so.1 not found in btrfs-progs"
      exit 1
    fi
    cp "$BTRFS_LIB" $out/lib/

    cp libpg_branch.so $out/lib/pg_branch.so
    cp *.control $out/share/postgresql/extension
    cp *.sql     $out/share/postgresql/extension

    patchelf --set-rpath "${btrfs-progs}/lib:${postgresql}/lib" $out/lib/pg_branch.so
  '';

  meta = with lib; {
    description = "pg_branch — btrfs-backed database branching for postgres";
    homepage    = "https://github.com/boltpl81/pg_branch";
    platforms   = postgresql.meta.platforms;
    license     = licenses.postgresql;
  };
}
