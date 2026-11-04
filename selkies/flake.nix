{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos/v2";
    nixpkgs.follows = "xnodeos/nixpkgs";
    selkies.url = "github:Openmesh-Network/xnode-packages?dir=selkies";
  };

  outputs = inputs: {
    nixosModules = {
      default =
        { pkgs, ... }@args:
        {
          imports = [
            inputs.selkies.nixosModules.default
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
              services.selkies.args = [
                "session"
                "--session=labwc"
                "--port=8080"
                "--enable-basic-auth=false"
              ];
              systemd.user.services.selkies.environment.SELKIES_WAYLAND = "true";

              # https://wiki.nixos.org/wiki/Accelerated_Video_Playback
              hardware.graphics = {
                enable = true;
                extraPackages = with pkgs; [
                  intel-media-driver
                  intel-vaapi-driver
                ];
              };

              programs.labwc.enable = true;

              # https://github.com/joske/labwc/blob/master/data/labwc-session.target
              systemd.user.targets.labwc-session = {
                description = "labwc session";
                documentation = [
                  "man:labwc(1)"
                  "man:systemd.special(7)"
                ];
                bindsTo = [ "graphical-session.target" ];
                wants = [ "graphical-session-pre.target" ];
                after = [ "graphical-session-pre.target" ];
              };
              systemd.tmpfiles.rules = [
                "d /home/xnode/.config/labwc 0755 xnode users -"
                "L+ /home/xnode/.config/labwc/environment 0755 xnode users - ${
                  let
                    uid = builtins.toString args.config.users.users.xnode.uid;
                    XDG_RUNTIME_DIR = "/run/user/${uid}";
                  in
                  pkgs.writeText "labwc-environment" ''
                    XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}
                    DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
                    LABWC_UPDATE_ACTIVATION_ENV=1
                  ''
                }"
                "L+ /home/xnode/.config/labwc/autostart 0755 xnode users - ${pkgs.writeText "labwc-autostart" ''
                  systemctl --user --no-block start labwc-session.target
                ''}"
                "L+ /home/xnode/.config/labwc/shutdown 0755 xnode users - ${pkgs.writeText "labwc-shutdown" ''
                  systemctl --user stop graphical-session.target
                ''}"
              ];

              programs.noctalia = {
                enable = true;
                systemd.enable = true;
              };

              users.users.xnode = {
                isNormalUser = true;
                linger = true;
                createHome = true;
                extraGroups = [
                  "input"
                  "video"
                  "render"
                ];
              };

              xnode.reverse-proxy.https = args.lib.mkIf (domain != "") {
                ${domain}."/".locations = [
                  {
                    domain = "127.0.0.1";
                    port = 8080;
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
