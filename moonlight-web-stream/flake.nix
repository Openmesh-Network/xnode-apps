{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos/v2";
    nixpkgs.follows = "xnodeos/nixpkgs";
    moonlight-web-stream.url = "github:Openmesh-Network/xnode-packages?dir=moonlight-web-stream";
  };

  outputs = inputs: {
    nixosModules = {
      default =
        { pkgs, ... }@args:
        {
          imports = [
            inputs.moonlight-web-stream.nixosModules.default
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
              type =
                if (builtins.pathExists "${args.config.xnode.xnode-config}/type") then
                  builtins.readFile "${args.config.xnode.xnode-config}/type"
                else
                  "";
            in
            {
              services.moonlight-web-stream.config = {
                web_server = {
                  first_login_create_admin = args.lib.mkDefault false;
                  first_login_assign_global_hosts = args.lib.mkDefault false;
                  bind_address = args.lib.mkDefault "127.0.0.1:8080";
                  forwarded_header = args.lib.mkIf (domain != "" && owner != "") {
                    username_header = args.lib.mkDefault "Xnode-Auth-User";
                    auto_create_missing_user = args.lib.mkDefault true;
                  };
                };
              };

              services.sunshine.enable = true;

              services.avahi.enable = false;

              hardware.uinput.enable = args.lib.mkIf (type == "virtual-machine") true;

              systemd.tmpfiles.rules = args.lib.mkIf (type == "container") [
                "d /run/udev 0755 root root -"
                "d /run/udev/data 0755 root root -"
                "f /run/udev/control 0666 root root -"
                "d /dev/input 0755 root root -"
              ];
              systemd.services.fake-udev = args.lib.mkIf (type == "container") {
                description = "Inject udev netlink events for container input devices";
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                  Restart = "on-failure";
                };
                script =
                  let
                    fake-udev =
                      let
                        subdir = "src/fake-udev";
                      in
                      pkgs.stdenv.mkDerivation {
                        name = "fake-udev";
                        version = "git-23062026";
                        src = pkgs.fetchFromGitHub {
                          owner = "games-on-whales";
                          repo = "wolf";
                          rev = "0a4e7665bfb4c9e0f73f1c7b6ee05cd61c7d5272";
                          sha256 = "sha256-+VAq3EKghHdm1vDg/jkfU1CxKw4afd5NRM57/dPVjOc=";
                          sparseCheckout = [
                            subdir
                          ];
                        };
                        sourceRoot = "source/${subdir}";
                        postPatch = ''
                          sed -i '1i cmake_minimum_required(VERSION 3.5)' CMakeLists.txt
                          sed -i 's/PUBLIC fake-udev\/fake-udev.hpp fake-udev\/MurmurHash2.h/PRIVATE fake-udev\/fake-udev.hpp fake-udev\/MurmurHash2.h/' CMakeLists.txt
                        '';
                        nativeBuildInputs = [ pkgs.cmake ];
                        buildInputs = [ pkgs.glibc.static ];
                        installPhase = ''
                          mkdir -p $out/bin
                          cp fake-udev $out/bin/
                        '';
                        meta = {
                          mainProgram = "fake-udev";
                        };
                      };
                  in
                  ''
                    # Watch for new /dev/input/event* devices
                    ${args.lib.getExe' pkgs.inotify-tools "inotifywait"} -m /dev/input -e create --format '%f' | \
                    while read DEVICE; do
                      case "$DEVICE" in
                        event*)
                          DEVPATH="/dev/input/$DEVICE"
                          MAJOR=$(stat -c '%t' "$DEVPATH" 2>/dev/null)
                          MINOR=$(stat -c '%T' "$DEVPATH" 2>/dev/null)
                          # Convert hex to decimal
                          MAJOR_DEC=$((16#$MAJOR))
                          MINOR_DEC=$((16#$MINOR))

                          INPUT_DIR=""
                          for d in /sys/devices/virtual/input/input*; do
                            if [ -e "$d/$DEVICE" ]; then
                              INPUT_DIR=$(basename "$d")
                              break
                            fi
                          done

                          if [ -z "$INPUT_DIR" ]; then
                            echo "Could not find input directory for $DEVICE" >&2
                            continue
                          fi

                          # Detect device type from name
                          NAME=$(cat /sys/class/input/$DEVICE/device/name 2>/dev/null || echo "")
                          case "$NAME" in
                            *"Keyboard"*|*"keyboard"*)
                              INPUT_PROPS="ID_INPUT=1\0ID_INPUT_KEYBOARD=1"
                              DB_PROPS="E:ID_INPUT=1\nE:ID_INPUT_KEY=1\nE:ID_INPUT_KEYBOARD=1"
                              ;;
                            *"Touch"*|*"touch"*)
                              INPUT_PROPS="ID_INPUT=1\0ID_INPUT_TOUCHSCREEN=1"
                              DB_PROPS="E:ID_INPUT=1\nE:ID_INPUT_TOUCHSCREEN=1"
                              ;;
                            *"Pen"*|*"pen"*)
                              INPUT_PROPS="ID_INPUT=1\0ID_INPUT_TABLET=1"
                              DB_PROPS="E:ID_INPUT=1\nE:ID_INPUT_TABLET=1"
                              ;;
                            *)
                              INPUT_PROPS="ID_INPUT=1\0ID_INPUT_MOUSE=1"
                              DB_PROPS="E:ID_INPUT=1\nE:ID_INPUT_MOUSE=1"
                              ;;
                          esac

                          # Write udev DB entry so libinput gets correct device type
                          printf "$DB_PROPS\nE:ID_SEAT=seat0\n" > "/run/udev/data/c''${MAJOR_DEC}:''${MINOR_DEC}"

                          # Send the actual netlink uevent that libinput's monitor receives
                          printf "%b" \
                            "ACTION=add\0DEVNAME=/dev/input/$DEVICE\0DEVPATH=/devices/virtual/input/$INPUT_DIR/$DEVICE\0SUBSYSTEM=input\0DEVTYPE=event\0MAJOR=$MAJOR_DEC\0MINOR=$MINOR_DEC\0SEQNUM=$RANDOM\0$INPUT_PROPS\0ID_SEAT=seat0\0" \
                            | base64 | ${args.lib.getExe fake-udev}

                                
                          echo "Spoofed udev event for $DEVICE"
                        ;;
                      esac
                    done
                  '';
              };

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
                  ''}";
                  Restart = "on-failure";
                };
              };

              services.pipewire = {
                enable = true;
                audio.enable = true;
                pulse.enable = true;
              };
              xdg.portal = {
                enable = true;
                wlr.enable = true;
              };

              services.sunshine.settings.capture = "wlr";

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
                ${domain}."/".locations =
                  let
                    split = args.lib.splitString ":" args.config.services.moonlight-web-stream.config.web_server.bind_address;
                  in
                  [
                    {
                      domain = builtins.elemAt split 0;
                      port = args.lib.toInt (builtins.elemAt split 1);
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
                    }
                    // (args.lib.mkIf (type == "container") {
                      "/dev/input" = {
                        path = "/run/vuinputd/vuinput/dev-input";
                        readonly = true;
                      };
                      "/dev/uinput" = {
                        path = "/dev/vuinput";
                        readonly = true;
                      };
                    });
                    device = {
                      allow = {
                        "char-drm" = {
                          read = true;
                          write = true;
                          mknod = false;
                        }
                        // (args.lib.mkIf (type == "container") {
                          "/dev/vuinput" = {
                            read = true;
                            write = true;
                            mknod = false;
                          };
                        });
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
