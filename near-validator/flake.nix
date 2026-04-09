{
  inputs = {
    near-validator.url = "github:Openmesh-Network/near-validator";
    nixpkgs.follows = "near-validator/nixpkgs";
  };

  outputs = inputs: {
    nixosModules = {
      default =
        { pkgs, ... }@args:
        {
          inputs = [
            inputs.near-validator.nixosModules.default
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
