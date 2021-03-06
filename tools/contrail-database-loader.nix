# This build a NixOs VM that load a casssandra dump and start the
# contrail API and Schema Transformer services.
#
# To generate a dump directory, use the following script:
# mkdir -p /tmp/cassandra-dump
# cqlsh -e "DESC SCHEMA" > /tmp/cassandra-dump/schema.cql
# for t in obj_uuid_table obj_fq_name_table; do
#   echo "COPY config_db_uuid.$t TO '/tmp/cassandra-dump/config_db_uuid.$t.csv';" | cqlsh
# done

{ pkgs
, pkgs_path ? <nixpkgs>
, contrailPkgs
}:

with import (pkgs_path + /nixos/lib/testing.nix) { system = builtins.currentSystem; };

let
  api = import ../test/configuration/R3.2/api.nix { inherit pkgs; };
  schemaTransformer = import ../test/configuration/R3.2/schema-transformer.nix { inherit pkgs; };
  cassandraDumpPath = "/tmp/xchg-shared/cassandra-dump/";

  machine = {pkgs, config, ...}: {
    imports = [ ../modules/contrail-database-loader.nix ];
    config = {
      _module.args = { inherit contrailPkgs; };
      services.openssh.enable = true;
      services.openssh.permitRootLogin = "yes";
      services.openssh.extraConfig = "PermitEmptyPasswords yes";
      users.extraUsers.root.password = "";

      contrail.databaseLoader = {
        inherit cassandraDumpPath;
        enable = true;

        apiConfigFile = api;
        schemaTransformerConfigFile = schemaTransformer;
      };
    };
  };
  vm = (makeTest { name = "contrail-database-loader"; nodes = { inherit machine; }; testScript = ""; }).driver;
in
pkgs.writeScript "contrail-database-loader-start" ''
  if [ ! -d  /tmp/xchg-shared/cassandra-dump ]
  then
    echo "You must first create a dump directory /tmp/xchg-shared/cassandra-dump that contains all required dump files"
    echo "To create these files:"
    echo '  mkdir -p /tmp/cassandra-dump'
    echo '  cqlsh -e "DESC SCHEMA" > /tmp/cassandra-dump/schema.cql'
    echo '  for t in obj_uuid_table obj_fq_name_table; do'
    echo '    echo "COPY config_db_uuid.$t TO '/tmp/cassandra-dump/config_db_uuid.$t.csv';" | cqlsh'
    echo '  done'
    echo 'Then get move /tmp/cassandra-dump to /tmp/xchg-shared/cassandra-dump'
    echo 'And replay this script'
    exit 1
  fi
  QEMU_NET_OPTS="hostfwd=tcp::2222-:22" ${vm}/bin/nixos-run-vms
''
