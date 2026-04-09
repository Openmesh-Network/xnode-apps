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
            services.openvscode-server.enable = true;
            services.openvscode-server.host = "0.0.0.0";

            networking.firewall.allowedTCPPorts = [ args.config.services.openvscode-server.port ];
          };
        };
    };
  };
}
