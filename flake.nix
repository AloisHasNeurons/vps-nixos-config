{
  description = "My Declarative NixOS VPS Config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Agenix secrets
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Disko for disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Minecraft
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
    };
  };

  outputs = {
    self,
    nixpkgs,
    agenix,
    disko,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = ["x86_64-linux"];
    forEachSystem = f:
      nixpkgs.lib.genAttrs systems (system:
        f {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        });
  in {
    nixosConfigurations = {
      # --- VPS ---
      vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./configuration.nix
          ./disk-config.nix
          ./modules/ipv6.nix # Separate: not imported by test VM (no enp1s0 there)
          # Agenix for secrets
          inputs.agenix.nixosModules.default
          # Disko
          disko.nixosModules.disko

          # Minecraft
          ./modules/minecraft.nix
          inputs.nix-minecraft.nixosModules.minecraft-servers
          {
            nixpkgs.overlays = [inputs.nix-minecraft.overlay];
            nixpkgs.config.allowUnfree = true;
          }
          ({
            config,
            pkgs,
            ...
          }: {
            virtualisation.vmVariant = {
              virtualisation = {
                graphics = false;
                memorySize = 2048;
                cores = 2;

                forwardPorts = [
                  {
                    from = "host";
                    host.port = 12222;
                    guest.port = 22;
                  } # SSH
                  {
                    from = "host";
                    host.port = 18080;
                    guest.port = 80;
                  } # Web
                  {
                    from = "host";
                    host.port = 18443;
                    guest.port = 443;
                  } # Web (SSL)
                  {
                    from = "host";
                    host.port = 13000;
                    guest.port = 3000;
                  } # AdGuard
                  {
                    from = "host";
                    host.port = 13001;
                    guest.port = 3001;
                  } # Homepage
                ];
              };

              # Use a dummy key for the VM since it cannot decrypt the real secret
              networking.wireguard.interfaces.wg0.privateKeyFile = pkgs.lib.mkForce "${pkgs.writeText "dummy-wg-key" "YF5X5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q4="}";
            };
          })
        ];
      };
    };

    # Package to build a VM for local tests
    packages = forEachSystem ({pkgs}: {
      vps-vm = self.nixosConfigurations.vps.config.system.build.vm;
    });

    # Checks (run by `nix flake check`)
    checks = forEachSystem ({pkgs}: {
      security = pkgs.callPackage ./tests/security.nix {inherit inputs;};
    });

    # Formatter for nix fmt
    formatter = forEachSystem ({pkgs}: pkgs.alejandra);

    devShells = forEachSystem ({pkgs}: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          just
          openssh
          agenix.packages.${system}.default
          terraform # Infrastructure as Code
        ];
      };
    });
  };
}
