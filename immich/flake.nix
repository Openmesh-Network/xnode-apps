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
            services.immich.enable = true;
            services.immich.host = "0.0.0.0";
            services.immich.openFirewall = true;
          };
        };
    };
  };
}
