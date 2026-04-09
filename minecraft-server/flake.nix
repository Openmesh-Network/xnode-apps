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
