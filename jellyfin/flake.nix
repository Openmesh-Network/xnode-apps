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
            services.jellyfin.enable = true;
            services.jellyfin.openFirewall = true;
          };
        };
    };
  };
}
