{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos/v1";
    nixpkgs.follows = "xnodeos/nixpkgs";
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs = inputs: {
    nixosModules = {
      default =
        { pkgs, ... }@args:
        {
          imports = [
            inputs.hermes-agent.nixosModules.default
            inputs.xnodeos.nixosModules.app
          ];

          config = {
            services.hermes-agent.enable = true;

            xnode.manager = {
              cache = [
                {
                  location = "https://cache.garnix.io";
                  public-keys = [ "CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
                }
              ];
            };
          };
        };
    };
  };
}
