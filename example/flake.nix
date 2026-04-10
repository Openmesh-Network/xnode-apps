{
  inputs = {
    app.url = "github:Openmesh-Network/xnode-apps?dir=example";
    nixpkgs.follows = "app/nixpkgs";
  };

  outputs = inputs: {
    nixosConfigurations.xnode = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.app.nixosModules.default
        (
          { pkgs, ... }@args:
          {
            xnode.xnode-config = ./xnode-config;

            # START USER CONFIG

            # END USER CONFIG
          }
        )
      ];
    };
  };
}
