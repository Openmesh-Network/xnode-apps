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
          imports = [
            inputs.xnodeos.nixosModules.app
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
              services.ollama.enable = true;
              services.ollama.package = args.lib.mkDefault pkgs.ollama-vulkan;
              services.ollama.user = "ollama";
              services.ollama.host = "127.0.0.1";
              services.nginx.virtualHosts.${domain}.locations."/" = {
                recommendedProxySettings = false; # Sets Host which breaks our custom Host
                extraConfig = ''
                  proxy_set_header Host ${args.config.services.ollama.host}:${builtins.toString args.config.services.ollama.port};
                '';
              };

              hardware.graphics.enable = true;

              xnode.reverse-proxy.https = args.lib.mkIf (domain != "") {
                ${domain}."/".locations = [
                  {
                    domain = args.config.services.ollama.host;
                    port = args.config.services.ollama.port;
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
