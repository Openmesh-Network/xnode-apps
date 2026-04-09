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
            services.nextcloud.enable = true;
            services.nextcloud.https = true;
            services.nextcloud.config.dbtype = "sqlite";
            services.nextcloud.settings.trusted_proxies = [ "192.168.0.0" ];

            networking.firewall.allowedTCPPorts = [ 80 ];
          };
        };
    };
  };
}
