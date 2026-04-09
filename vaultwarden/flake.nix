{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs = inputs: {
    nixosModules = {
      default =
        { pkgs, ... }@args:
        {
          config = {
            services.vaultwarden.enable = true;
            services.vaultwarden.config.ROCKET_ADDRESS = "0.0.0.0";
            services.vaultwarden.config.ROCKET_PORT = 8222;
            services.vaultwarden.configurePostgres = true;

            networking.firewall.allowedTCPPorts = [ args.config.services.vaultwarden.config.ROCKET_PORT ];
          };
        };
    };
  };
}
