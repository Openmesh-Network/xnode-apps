{
  inputs = {
    vllm.url = "github:Openmesh-Network/xnode-packages?dir=vllm/xpu";
    nixpkgs.follows = "vllm/nixpkgs";
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
            inputs.vllm.nixosModules.default
            inputs.xnodeos.nixosModules.app
          ];

          config = {
            services.vllm.enable = true;

            xnode.manager = {
              permission = {
                container = {
                  bind = {
                    "/dev/dri" = {
                      path = "/dev/dri";
                      readonly = true;
                    };
                  };
                  device = {
                    allow = {
                      "char-drm" = {
                        read = true;
                        write = true;
                        mknod = false;
                      };
                    };
                  };
                  extra_args = [
                    "--network-veth"
                    "--private-users=managed"
                    "--private-users-ownership=foreign"
                  ];
                };
              };
            };
          };
        };
    };
  };
}
