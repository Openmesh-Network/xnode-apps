{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos/v2";
    nixpkgs.follows = "xnodeos/nixpkgs";
    vllm-omni.url = "github:Openmesh-Network/xnode-packages?dir=vllm-omni/xpu";
    vllm.follows = "vllm-omni/vllm";
    intel-oneapi-toolkit.follows = "vllm/intel-oneapi-toolkit";
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
            nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (args.lib.getName pkg) [ "intel-ocl" ];

            services.vllm.package = inputs.vllm-omni.packages.${pkgs.stdenv.hostPlatform.system}.vllm-omni;
            systemd.services.vllm.path = [
              inputs.intel-oneapi-toolkit.packages.${pkgs.stdenv.hostPlatform.system}.intel-ocloc
            ];
            systemd.services.vllm.environment = {
              "LD_LIBRARY_PATH" = "/run/opengl-driver/lib:${
                inputs.vllm-omni.extras.${pkgs.stdenv.hostPlatform.system}.venv
              }/lib:${pkgs.libsndfile.out}/lib";
              "LIBRARY_PATH" = "${pkgs.level-zero}/lib";
              "CPATH" = "${pkgs.level-zero}/include";
              "CC" = "${pkgs.llvmPackages.stdenv.cc}/bin/cc";
              "CXX" = "${pkgs.llvmPackages.stdenv.cc}/bin/c++";
              "UR_L0_ENABLE_RELAXED_ALLOCATION_LIMITS" = "1";
              "VLLM_XPU_ENABLE_XPU_GRAPH" = "1";
            };

            hardware.graphics = {
              enable = true;
              extraPackages = [
                pkgs.intel-compute-runtime
                pkgs.intel-compute-runtime.drivers
                pkgs.level-zero
                pkgs.intel-graphics-compiler
                pkgs.intel-ocl
                pkgs.ocl-icd
              ];
            };

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
