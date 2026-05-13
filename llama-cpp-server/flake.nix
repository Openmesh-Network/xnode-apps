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
            (
              {
                config,
                pkgs,
                lib,
                ...
              }:
              let
                cfg = config.services.llama-cpp-server;
              in
              {
                options = {
                  services.llama-cpp-server = {
                    enable = lib.mkEnableOption "llama.cpp model server";

                    package = lib.mkOption {
                      type = lib.types.package;
                      default = pkgs.llama-cpp-vulkan;
                      example = pkgs.llama-cpp;
                      description = ''
                        llama.cpp compatible package to use.
                      '';
                    };

                    host = lib.mkOption {
                      type = lib.types.str;
                      default = "127.0.0.1";
                      example = "0.0.0.0";
                      description = ''
                        Address to serve the model on.
                      '';
                    };

                    port = lib.mkOption {
                      type = lib.types.port;
                      default = 8080;
                      example = 8000;
                      description = ''
                        Port to serve the model under.
                      '';
                    };

                    model = lib.mkOption {
                      type = lib.types.path;
                      example = pkgs.fetchurl {
                        name = "llama-cpp-server-model";
                        url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
                        hash = "sha256-cHpVqKQ5fs3kTeDEmdPmjBrR0kDR2mWCa0lJ0QQ/RFA=";
                      };
                      description = ''
                        Model to serve.
                      '';
                    };

                    jinja = {
                      enable = lib.mkEnableOption "jinja template engine" // {
                        default = true;
                      };
                    };

                    extraArgs = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                      example = [
                        "--temp"
                        (builtins.toString 0.7)
                        "--top-p"
                        (builtins.toString 0.8)
                        "--presence-penalty"
                        (builtins.toString 1.5)
                        "--top-k"
                        (builtins.toString 20)
                        "--chat-template-kwargs"
                        "'{\"enable_thinking\": false}'"
                      ];
                      description = ''
                        Additional arguments to pass to llama-server.
                      '';
                    };
                  };
                };

                config = lib.mkIf cfg.enable {
                  users.groups.llama-cpp-server = { };
                  users.users.llama-cpp-server = {
                    isSystemUser = true;
                    group = "llama-cpp-server";
                  };

                  systemd.services.llama-cpp-server = {
                    wantedBy = [ "multi-user.target" ];
                    description = "llama.cpp model server";
                    after = [ "network.target" ];
                    serviceConfig = {
                      ExecStart =
                        let
                          args = [
                            "--host"
                            "\"${cfg.host}\""
                            "--port"
                            (builtins.toString cfg.port)
                            "--model"
                            "\"${cfg.model}\""
                            (lib.optionalString cfg.jinja.enable "--jinja")
                          ];
                        in
                        "${lib.getExe' cfg.package "llama-server"} ${builtins.concatStringsSep " " args}";
                      User = "llama-cpp-server";
                      Group = "llama-cpp-server";
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
              services.llama-cpp-server.enable = true;

              hardware.graphics.enable = true;

              xnode.reverse-proxy.https = args.lib.mkIf (domain != "") {
                ${domain}."/".locations = [
                  {
                    domain = args.config.services.llama-cpp-server.host;
                    port = args.config.services.llama-cpp-server.port;
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
