# This file was generated by https://github.com/kamilchm/go2nix v1.2.1
{ stdenv, buildGoPackage, fetchgit, fetchhg, fetchbzr, fetchsvn }:

buildGoPackage rec {
  name = "contrail-gremlin-${version}";
  version = "2018-01-23";
  rev = "26a6c607c29ca768c77642681aba5bd93fa242a5";

  goPackagePath = "github.com/eonpatapon/contrail-gremlin";

  src = fetchgit {
    inherit rev;
    url = "https://github.com/eonpatapon/contrail-gremlin.git";
    sha256 = "15206w8w7gng03cqpnaz9yqwc9q46i5xaciizgqgpxlc8n9n2x2r";
  };

  goDeps = ./deps.nix;

  postInstall = ''
    mkdir -p $bin/conf
    cp -v go/src/github.com/eonpatapon/contrail-gremlin/conf/* $bin/conf
  '';

  # TODO: add metadata https://nixos.org/nixpkgs/manual/#sec-standard-meta-attributes
  meta = {
  };
}
