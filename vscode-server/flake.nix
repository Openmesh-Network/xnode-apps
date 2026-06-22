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
              services.openvscode-server.enable = true;
              services.openvscode-server.withoutConnectionToken = true;

              xnode.reverse-proxy.https = args.lib.mkIf (domain != "") {
                ${domain}."/".locations = [
                  {
                    domain = args.config.services.openvscode-server.host;
                    port = args.config.services.openvscode-server.port;
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
