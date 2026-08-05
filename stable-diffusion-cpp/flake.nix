{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos/v2";
    nixpkgs.follows = "xnodeos/nixpkgs";
  };

  outputs = inputs: {
    nixosModules = {
      default =
        { pkgs, ... }@args:
        {
          imports = [
            inputs.xnodeos.nixosModules.app
            (
              let
                cfg = args.config.services.stable-diffusion-cpp;
              in
              {
                options = {
                  services.stable-diffusion-cpp = {
                    enable = args.lib.mkEnableOption "Enable stable-diffusion-cpp.";

                    package = args.lib.mkOption {
                      type = args.lib.types.package;
                      default = pkgs.stable-diffusion-cpp;
                      description = ''
                        stable-diffusion-cpp equivalent executable.
                      '';
                    };

                    args = args.lib.mkOption {
                      type = args.lib.types.listOf args.lib.types.str;
                      default = [ ];
                      description = ''
                        cli args to pass to stable-diffusion-cpp executable.
                      '';
                    };
                  };
                };

                config = args.lib.mkIf cfg.enable {
                  users.groups.stable-diffusion-cpp = { };
                  users.users.stable-diffusion-cpp = {
                    isSystemUser = true;
                    group = "stable-diffusion-cpp";
                    home = "/var/lib/stable-diffusion-cpp";
                    createHome = true;
                  };
                  systemd.services.stable-diffusion-cpp = {
                    wantedBy = [ "multi-user.target" ];
                    serviceConfig = {
                      ExecStart = "${args.lib.getExe' cfg.package "sd-server"} ${builtins.concatStringsSep " " (builtins.map args.lib.escapeShellArg cfg.args)}";
                      Restart = args.lib.mkDefault "on-failure";
                      User = "stable-diffusion-cpp";
                      Group = "stable-diffusion-cpp";
                      WorkingDirectory = "/var/lib/stable-diffusion-cpp";
                      StateDirectory = "stable-diffusion-cpp";
                    };
                  };
                };
              }
            )
          ];

          config =
            let
              domain =
                if (builtins.pathExists "${args.config.xnode.xnode-config}/domain") then
                  builtins.readFile "${args.config.xnode.xnode-config}/domain"
                else
                  "";
              owner =
                if (builtins.pathExists "${args.config.xnode.xnode-config}/owner") then
                  builtins.readFile "${args.config.xnode.xnode-config}/owner"
                else
                  "";
            in
            {
              services.stable-diffusion-cpp.enable = true;
              services.stable-diffusion-cpp.package = args.lib.mkDefault pkgs.stable-diffusion-cpp-vulkan;

              hardware.graphics.enable = true;

              xnode.reverse-proxy.https = args.lib.mkIf (domain != "") {
                ${domain}."/".locations = [
                  {
                    domain = "127.0.0.1";
                    port = 1234;
                  }
                ];
              };

              services.xnode-auth.domains = args.lib.mkIf (domain != "" && owner != "") {
                ${domain} = {
                  accessList = {
                    users = {
                      ${owner} = {
                        roles = [ "owner" ];
                      };
                    };
                    roles = {
                      "owner" = { };
                    };
                  };
                  paths = builtins.attrNames args.config.xnode.reverse-proxy.https.${domain};
                };
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
