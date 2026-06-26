{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos/v2";
    nixpkgs.follows = "xnodeos/nixpkgs";
    erpc.url = "github:Openmesh-Network/xnode-packages?dir=erpc";
  };

  outputs = inputs: {
    nixosModules = {
      default =
        { pkgs, ... }@args:
        {
          imports = [
            inputs.erpc.nixosModules.default
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
              services.erpc.config = args.lib.mkDefault {
                server = {
                  listenV4 = true;
                  httpHostV4 = "127.0.0.1";
                  httpPortV4 = 4000;
                };
              };

              xnode.reverse-proxy.https = args.lib.mkIf (domain != "") {
                ${domain}."/".locations = [
                  {
                    domain = args.config.services.erpc.config.server.httpHostV4;
                    port = args.config.services.erpc.config.server.httpPortV4;
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
            };
        };
    };
  };
}
