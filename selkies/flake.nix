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

              programs.sway.enable = true;
              programs.sway.extraSessionCommands = ''
                export WLR_BACKENDS=headless,libinput;
                export WLR_LIBINPUT_NO_DEVICES=1;
                export LIBSEAT_BACKEND=noop;
                export WLR_SCENE_DISABLE_DIRECT_SCANOUT=0;
                export WLR_NO_HARDWARE_CURSORS=1;
              '';
              systemd.user.services.sway-headless = {
                description = "Headless sway";
                wantedBy = [ "default.target" ];
                requires = [ "dbus.socket" ];
                after = [ "dbus.socket" ];
                path = args.config.environment.systemPackages;
                unitConfig = {
                  ConditionUser = "!root";
                };
                serviceConfig = {
                  ExecStart = "${args.lib.getExe args.config.programs.sway.package} --config ${pkgs.writeText "sway-config" ''
                    include /etc/sway/config

                    # https://github.com/daaaaan/sunshine-headless-sway/blob/master/sway-sunshine/config
                    # Default headless output - 1080p fallback, Sunshine prep commands override this
                    output HEADLESS-1 resolution 1920x1080@60Hz

                    # Performance tuning
                    output * allow_tearing yes
                    output * max_render_time off

                    # Dark background
                    exec swaybg -c '#1a1a2e'
                  ''}";
                  Restart = "on-failure";
                };
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
