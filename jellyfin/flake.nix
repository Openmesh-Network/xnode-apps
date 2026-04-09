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
            services.jellyfin.enable = true;
            services.jellyfin.openFirewall = true;
          };
        };
    };
  };
}
