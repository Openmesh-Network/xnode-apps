{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos/v2";
    nixpkgs.follows = "xnodeos/nixpkgs";
    near-validator.url = "github:Openmesh-Network/near-validator";
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
