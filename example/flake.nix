{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos";
    app.url = "github:Openmesh-Network/xnode-apps?dir=example";
    nixpkgs.follows = "app/nixpkgs";
  };

  outputs = inputs: {
    nixosConfigurations.xnode = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.xnodeos.nixosModules.app
        {
          xnode.xnode-config = ./xnode-config;
        }
        inputs.my-app.nixosModules.default
        (
          { pkgs, ... }@args:
          {
            # START USER CONFIG

            # END USER CONFIG
          }
        )
      ];
    };
  };
}
