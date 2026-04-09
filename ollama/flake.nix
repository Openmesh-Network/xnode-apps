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
            services.ollama.enable = true;
            services.ollama.user = "ollama";
            services.ollama.host = "0.0.0.0";
            services.ollama.openFirewall = true;
          };
        };
    };
  };
}
