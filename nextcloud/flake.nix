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
              services.nextcloud.enable = true;
              services.nextcloud.https = args.lib.mkIf (domain != "") true;
              services.nextcloud.hostName = if (domain != "") then domain else "localhost";
              services.nextcloud.database.createLocally = true;
              services.nextcloud.config.dbtype = "pgsql";
              services.nextcloud.config.adminpassFile =
                if args.config.xnode.secret.values ? password then
                  args.config.xnode.secret.values.password
                else
                  builtins.toString (pkgs.writeText "password" "xnode");
              services.nextcloud.extraApps = {
                inherit (args.config.services.nextcloud.package.packages.apps) richdocuments;
              };

              xnode.reverse-proxy.enable = true;
              services.nginx.virtualHosts.${args.config.services.nextcloud.hostName} = {
                forceSSL = true;
                enableACME = true;
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
                  paths = [
                    "~ \\.php(?:$|/)"
                    "~ \\.(?:css|js|mjs|svg|gif|ico|jpg|jpeg|png|webp|wasm|tflite|map|html|ttf|bcmap|mp4|webm|ogg|flac)$"
                    "~ ^\\/(?:updater|ocs-provider)(?:$|\\/)"
                    "/"
                  ];
                };
              };

              services.nginx.validateConfigFile = args.lib.mkIf args.config.services.xnode-auth.enable false; # gixy add_header_redefinition fail
            };
        };
    };
  };
}
