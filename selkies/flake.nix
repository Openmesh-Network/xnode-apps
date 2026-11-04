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
                "--session=${pkgs.writeShellScript "labwc-wrapped" ''
                  exec ${args.lib.getExe args.config.programs.labwc.package} -C ${
                    pkgs.linkFarm "labwc-config" [
                      {
                        # https://docs.noctalia.dev/noctalia/compositor-settings/labwc/
                        name = "rc.xml";
                        path =
                          (pkgs.formats.xml {
                            format = "badgerfish";
                            withHeader = true;
                          }).generate
                            "rc.xml"
                            {
                              labwc_config = {
                                core.gap = "10";
                                windowSwitcher = {
                                  "@preview" = "no";
                                  "@outlines" = "yes";
                                  osd = {
                                    "@style" = "thumbnail";
                                  };
                                };
                                mouse = [
                                  { default = { }; }
                                  {
                                    context = {
                                      "@name" = "Root";
                                      mousebind = [
                                        {
                                          "@button" = "Left";
                                          "@action" = "Press";
                                          action = {
                                            "@name" = "None";
                                          };
                                        }
                                        {
                                          "@button" = "Right";
                                          "@action" = "Press";
                                          action = {
                                            "@name" = "None";
                                          };
                                        }
                                      ];
                                    };
                                  }
                                ];
                              };
                            };
                      }
                      {
                        name = "autostart";
                        path = pkgs.writeShellScript "labwc-autostart" ''
                          export XDG_RUNTIME_DIR="/run/user/$(id -u)"
                          export DBUS_SESSION_BUS_ADDRESS="unix:path=''${XDG_RUNTIME_DIR}/bus"
                          LABWC_SOCKET=$(find "$XDG_RUNTIME_DIR"/selkies-session-* -maxdepth 1 -name 'wayland-*' -type s 2>/dev/null | head -1)
                          WAYLAND_DISPLAY=$LABWC_SOCKET systemctl --user import-environment WAYLAND_DISPLAY
                          systemctl --user --no-block start labwc-session.target
                        '';
                      }
                      {
                        name = "shutdown";
                        path = pkgs.writeShellScript "labwc-shutdown" ''
                          export XDG_RUNTIME_DIR="/run/user/$(id -u)"
                          export DBUS_SESSION_BUS_ADDRESS="unix:path=''${XDG_RUNTIME_DIR}/bus"
                          systemctl --user stop graphical-session.target
                        '';
                      }
                    ]
                  } "$@"
                ''}"
                "--port=8080"
                "--enable-basic-auth=false"
              ];
              systemd.user.services.selkies.path = [
                pkgs.bash
                args.config.services.pulseaudio.package
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

              programs.noctalia = {
                enable = true;
                systemd.enable = true;
              };
              systemd.tmpfiles.rules = [
                "d /home/xnode/.config/noctalia 0755 xnode xnode -"
                "L+ /home/xnode/.config/noctalia/config.toml - - - - ${
                  (pkgs.formats.toml { }).generate "noctalia-config.toml" {
                    bar.default = {
                      auto_hide = true;
                      reserve_space = false;
                      background_opacity = 0.85;
                      margin_ends = 0;
                      start = [ ];
                      center = [
                        "media"
                        "clock"
                      ];
                      end = [
                        "tray"
                        "clipboard"
                        "notifications"
                      ];
                    };
                    shell = {
                      setup_wizard_enabled = false;
                      launch_apps_as_systemd_services = true;
                    };
                    dock = {
                      enabled = true;
                      icon_size = 36;
                      auto_hide = true;
                      reserve_space = false;
                      launcher_position = "start";
                      pinned = builtins.map (
                        p: p.meta.mainProgram or p.pname or (builtins.parseDrvName p.name).name
                      ) args.config.users.users.xnode.packages;
                    };
                    control_center.sidebar_section = "none";
                  }
                }"
              ];

              services.pipewire.enable = false;
              services.pulseaudio.enable = true;

              users.users.xnode = {
                isNormalUser = true;
                linger = true;
                createHome = true;
                extraGroups = [
                  "input"
                  "video"
                  "render"
                  "audio"
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
