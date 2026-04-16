{
  inputs = {
    openclaw.url = "github:openclaw/nix-openclaw";
    nixpkgs.follows = "openclaw/nixpkgs";
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
            inputs.openclaw.nixosModules.openclaw-gateway
            inputs.xnodeos.nixosModules.app
          ];

          config = {
            services.openclaw-gateway.enable = true;
            services.openclaw-gateway.package =
              inputs.openclaw.packages.${pkgs.stdenv.hostPlatform.system}.openclaw-gateway;
            services.openclaw-gateway.config.gateway.mode = "local";
            services.openclaw-gateway.config.gateway.auth.token =
              "69152a9fff0cf22cff72ec21d7324c997cdf435e4ec5bde9";
          };
        };
    };
  };
}
