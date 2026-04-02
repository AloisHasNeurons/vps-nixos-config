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
    pythonPyhumpsOverlay = _: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (_: python-prev: {
            pyhumps = python-prev.pyhumps.overridePythonAttrs (_: {
              # Bypass upstream patch that fails to apply
              patches = [];
              doCheck = false;
            });
          })
        ];
    };

    forEachSystem = f:
      nixpkgs.lib.genAttrs systems (system:
        f {
          inherit system;
          pkgs = import nixpkgs {
            inherit system;
            overlays = [pythonPyhumpsOverlay];
            config.allowUnfree = true;
          };
        });
  in {
    nixosConfigurations = {
      # --- VPS ---
      vps = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./configuration.nix
          ./disk-config.nix
          ./modules/ipv6.nix # Separate: not imported by test VM (no enp1s0 there)
          # Agenix for secrets
          inputs.agenix.nixosModules.default
          # Disko
          disko.nixosModules.disko
          # Platform
          {nixpkgs.hostPlatform = "x86_64-linux";}

          # Minecraft
          ./modules/minecraft.nix
          inputs.nix-minecraft.nixosModules.minecraft-servers
          {
            nixpkgs.overlays = [
              inputs.nix-minecraft.overlay
              pythonPyhumpsOverlay
            ];
            nixpkgs.config.allowUnfree = true;
          }
          ({...}: {
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
            };
          })
        ];
      };
    };

    # Package to build a VM for local tests
    packages = forEachSystem ({...}: {
      vps-vm = self.nixosConfigurations.vps.config.system.build.vm;
    });

    # Checks (run by `nix flake check`)
    checks = forEachSystem ({pkgs, ...}: {
      security = pkgs.callPackage ./tests/security.nix {inherit inputs;};
      services = pkgs.callPackage ./tests/services.nix {inherit inputs;};
    });

    # Formatter for nix fmt
    formatter = forEachSystem ({pkgs, ...}: pkgs.alejandra);

    devShells = forEachSystem ({
      pkgs,
      system,
    }: {
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
