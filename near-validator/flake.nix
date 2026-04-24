{
  inputs = {
    near-validator.url = "github:Openmesh-Network/near-validator";
    nixpkgs.follows = "near-validator/nixpkgs";
    xnodeos = {
      url = "github:Openmesh-Network/xnodeos/WIP";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    nixosModules = {
      default =
        { pkgs, ... }@args:
        {
          imports = [
            inputs.near-validator.nixosModules.default
            inputs.xnodeos.nixosModules.app
          ];

          config = {
            xnode.manager.cache = [
              {
                location = "https://openmesh.cachix.org";
                public-keys = [ "du4NDeMWxcX8T5GddfuD0s/Tosl3+6b+T2+CLKHgXvQ=" ];
              }
            ];

            services.near-validator.enable = true;

            networking.firewall.allowedTCPPorts = [
              3030
              24567
            ];
          };
        };
    };
  };
}
