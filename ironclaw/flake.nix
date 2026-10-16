{
  inputs = {
    xnodeos.url = "github:Openmesh-Network/xnodeos/v2";
    nixpkgs.follows = "xnodeos/nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = inputs: {
    nixosModules = {
      default =
        { pkgs, config, ... }:
        let
          env = config.systemd.services.ironclaw.environment;
        in
        {
          imports = [
            inputs.xnodeos.nixosModules.app
          ];

          config = {
            assertions = [
              {
                assertion = builtins.stringLength (env.IRONCLAW_REBORN_WEBUI_TOKEN or "") >= 32;
                message = "ironclaw: set IRONCLAW_REBORN_WEBUI_TOKEN to at least 32 characters.";
              }
            ];

            systemd.services.ironclaw = {
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              environment = {
                IRONCLAW_REBORN_HOME = "/var/lib/ironclaw";
                IRONCLAW_REBORN_WORKSPACE_ROOT = "/var/lib/ironclaw/workspace";
                IRONCLAW_REBORN_PROFILE = "local-dev";
                # Default backend is NEAR AI Cloud; use the node's own model.
                LLM_BACKEND = "openai_compatible";
                LLM_REQUEST_TIMEOUT_SECS = "600";
                HOME = "/var/lib/ironclaw";
              };
              serviceConfig = {
                # serve ignores the host/port env vars; only flags work. "::" also takes IPv4, and the mesh is IPv6.
                ExecStart = "${
                  inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.ironclaw
                }/bin/ironclaw serve --host :: --port 3000";
                DynamicUser = true;
                StateDirectory = "ironclaw";
                WorkingDirectory = "/var/lib/ironclaw";
                Restart = "on-failure";
              };
            };

            networking.firewall.allowedTCPPorts = [ 3000 ];

            xnode.manager = {
              cache = [
                {
                  location = "https://cache.numtide.com";
                  public-keys = [ "DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
                }
              ];
            };
          };
        };
    };
  };
}
