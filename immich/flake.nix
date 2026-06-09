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
              services.immich.enable = true;
              services.immich.host = "127.0.0.1";
              services.immich.settings.server.externalDomain = args.lib.mkIf (domain != "") "https://${domain}";

              xnode.reverse-proxy.https = args.lib.mkIf (domain != "") {
                ${domain}."/".locations = [
                  {
                    domain = args.config.services.immich.host;
                    port = args.config.services.immich.port;
                  }
                ];
              };

              # https://docs.immich.app/administration/reverse-proxy#nginx-example-config
              services.nginx.virtualHosts = args.lib.mkIf (domain != "") {
                ${domain}.extraConfig = ''
                  client_max_body_size 50000M;
                  proxy_request_buffering off;
                  client_body_buffer_size 1024k;
                '';
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
            };
        };
    };
  };
}
