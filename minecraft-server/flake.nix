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
            nixpkgs.config.allowUnfreePredicate =
              pkg: builtins.elem (args.lib.getName pkg) [ "minecraft-server" ];
            services.minecraft-server.enable = true;
            services.minecraft-server.eula = true;
            services.minecraft-server.declarative = true;
            services.minecraft-server.openFirewall = true;
          };
        };
    };
  };
}
