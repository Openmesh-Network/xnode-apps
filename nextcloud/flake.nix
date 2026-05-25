{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos/v1";
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
              services.nextcloud.enable = true;
              services.nextcloud.https = true;
              services.nextcloud.database.createLocally = true;
              services.nextcloud.config.dbtype = "pgsql";
              services.nextcloud.hostName = args.lib.mkIf (domain != "") domain;

              networking.firewall.allowedTCPPorts = [
                443
              ];

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
                };
              };
            };
        };
    };
  };
}
