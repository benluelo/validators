{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    union.url = "github:unionlabs/union/prep-testnet-8";
    # sops-nix.url = "github:Mic92/sops-nix";
  };
  outputs = { self, nixpkgs, union, ... }:
    {
      nixosConfigurations.bonlulu =
        let
          system = "x86_64-linux";
          domain = "testnet.bonlulu.uno";
          pkgs = import nixpkgs { inherit system; };
          explorer = pkgs.mkYarnPackage {
            src = pkgs.fetchFromGitHub {
              owner = "hussein-aitlahcen";
              repo = "explorer";
              rev = "b4c23b94fe3245dddf0185e54b39dbb97117efa6";
              hash = "sha256-9S4XS6f7CliujM4AKq/AkII9wxI/ANsGrHd5GqXTUxE=";
            };
            configurePhase = ''
              cp -r $node_modules node_modules
              chmod +w node_modules
              substituteInPlace src/chains/testnet/union.json \
                --replace 0xc0dejug.uno testnet.bonlulu.uno

            '';
            buildPhase = ''
              export HOME=$(mktemp -d)
              yarn --ignore-engine --offline build
            '';
            installPhase = ''
              mkdir -p $out
              mv dist/* $out/
            '';
            distPhase = "true";
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            union.nixosModules.unionvisor
            # sops-nix.nixosModules.sops
            "${nixpkgs}/nixos/modules/virtualisation/openstack-config.nix"
            {
              system.stateVersion = "23.11";

              # sops = {
              #   age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
              #   secrets = {
              #     datadog_api_key = {
              #       restartUnits = [ "datadog-agent.service" ];
              #       path = "/etc/datadog-agent/datadog_api.key";
              #       sopsFile = ./secrets/datadog.yaml;
              #       mode = "0440";
              #       owner = "datadog";
              #     };
              #     priv_validator_key = {
              #       restartUnits = [ "unionvisor.service" ];
              #       format = "binary";
              #       sopsFile = ./secrets/wakey-rpc/priv_validator_key.json;
              #       path = "/var/lib/unionvisor/home/config/priv_validator_key.json";
              #     };
              #   };
              # };

              networking.firewall.allowedTCPPorts = [ 80 443 26656 26657 ];
              # networking.firewall.extraCommands = ''
              #   iptables -A INPUT -s <IP ADDRESS> -j REJECT
              # '';

              services.unionvisor = {
                enable = true;
                moniker = "bonlulu";
                network = "union-testnet-7";
                bundle = union.packages.${system}.bundle-testnet-8;
              };

              security.acme = {
                acceptTerms = true;
                defaults.email = "acme@luelo.dev";
              };

              services.nginx = {
                enable = true;
                recommendedGzipSettings = true;
                recommendedOptimisation = true;
                recommendedProxySettings = true;
                recommendedTlsSettings = true;
                virtualHosts =
                  let
                    redirect = subdomain: port: {
                      "${subdomain}.${domain}" = {
                        locations = {
                          "/" = {
                            proxyPass = "http://127.0.0.1:${toString port}";
                            proxyWebsockets = true;
                          };
                        };
                        enableACME = true;
                        forceSSL = true;
                        extraConfig = ''
                          add_header Access-Control-Allow-Origin *;
                          add_header Access-Control-Max-Age 3600;
                          add_header Access-Control-Expose-Headers Content-Length;
                        '';
                      };
                    };

                    redirectGrpc = subdomain: port: {
                      "${subdomain}.${domain}" = {
                        enableACME = true;
                        forceSSL = true;
                        locations = {
                          "/" = {
                            extraConfig = ''
                              grpc_pass grpc://127.0.0.1:${toString port};
                              grpc_read_timeout      600;
                              grpc_send_timeout      600;
                              proxy_connect_timeout  600;
                              proxy_send_timeout     600;
                              proxy_read_timeout     600;
                              send_timeout           600;
                              proxy_request_buffering off;
                              proxy_buffering off;
                            '';
                          };
                        };
                      };
                    };
                  in
                  redirect "rpc" 26657
                  // redirect "api" 1317
                  // redirectGrpc "grpc" 9090
                  // redirect "grpc-web" 9091
                  // {
                    "${domain}" = {
                      enableACME = true;
                      forceSSL = true;
                      default = true;
                      root = "${explorer}";
                      locations."/" = {
                        extraConfig = ''
                          try_files $uri /index.html;
                        '';
                      };
                    };
                  };
              };

              nix = {
                settings = { auto-optimise-store = true; };
                gc = {
                  automatic = true;
                  dates = "weekly";
                  options = "--delete-older-than 15d";
                };
              };

              users.users.datadog.extraGroups = [ "systemd-journal" ];
              users.users.dd-agent.extraGroups = [ "systemd-journal" ];
              users.users.dd-agent.isSystemUser = true;
              users.users.dd-agent.group = "dd-agent";
              users.groups.dd-agent = { };

              services.datadog-agent = {
                enable = true;
                apiKeyFile = "/etc/datadog-agent/datadog_api.key";
                enableLiveProcessCollection = true;
                enableTraceAgent = true;
                site = "datadoghq.com";
                # extraIntegrations = { openmetrics = _: [ ]; };
                extraConfig = { logs_enabled = true; logs_config = { }; };
                checks = {
                  journald = { logs = [{ type = "journald"; }]; };
                  # openmetrics = {
                  #   init_configs = { };
                  #   instances = [
                  #     # metrics are stupid expensive and i don't need them for now
                  #     # {
                  #     #   openmetrics_endpoint = "http://localhost:26660/metrics";
                  #     #   namespace = "cometbft";
                  #     #   metrics = [
                  #     #     ".*"
                  #     #   ];
                  #     # }
                  #   ];
                  # };
                };
              };

              environment.systemPackages = with pkgs; [
                bat
                bottom
                helix
                jq
                neofetch
                tree
                kitty
              ];
            }
          ];
        };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
