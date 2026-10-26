{
  description = "Dhun Commons — three-party seasonal treasury and coordination wallet for Logos Basecamp";

  # Pre-built artifacts from the Logos Attic binary cache. The lez_core
  # dependency compiles wallet_ffi (Rust) and zk circuits; without this cache a
  # cold build runs for a very long time.
  nixConfig = {
    extra-substituters = [ "https://cache.nix.logos.co/public" ];
    extra-trusted-public-keys = [ "public:l4HrXgL4nw246+LBh2SOJyhz64BoGegOYLheT/iIAPU=" ];
  };

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    nix-bundle-lgx.url = "github:logos-co/nix-bundle-lgx";
    lez_core.url = "github:logos-blockchain/logos-execution-zone-module?rev=51a6fee385eedfdc65ba71f01447c5411a54bdf7";
  };

  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
