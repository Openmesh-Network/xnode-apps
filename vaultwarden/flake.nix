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
          imports = [
            inputs.xnodeos.nixosModules.app
          ];

          config = {
            services.vaultwarden.enable = true;
            services.vaultwarden.config.ROCKET_ADDRESS = "0.0.0.0";
            services.vaultwarden.config.ROCKET_PORT = 8222;
            services.vaultwarden.dbBackend = "postgresql";
            services.vaultwarden.configurePostgres = true;

            networking.firewall.allowedTCPPorts = [ args.config.services.vaultwarden.config.ROCKET_PORT ];
          };
        };
    };
  };
}
