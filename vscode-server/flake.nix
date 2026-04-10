{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
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
          inputs = [
            inputs.xnodeos.nixosModules.app
          ];

          config = {
            services.openvscode-server.enable = true;
            services.openvscode-server.host = "0.0.0.0";

            networking.firewall.allowedTCPPorts = [ args.config.services.openvscode-server.port ];
          };
        };
    };
  };
}
