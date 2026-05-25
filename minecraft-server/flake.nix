{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos/v1";
    nixpkgs.follows = "xnodeos/nixpkgs";
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
