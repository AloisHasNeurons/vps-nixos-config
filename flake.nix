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
  };

  outputs = {
    self,
    nixpkgs,
    agenix,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = ["x86_64-linux"];
    forEachSystem = f: nixpkgs.lib.genAttrs systems (system: f {
      pkgs = import nixpkgs { inherit system; };
    });
  in {
    nixosConfigurations = {
      # --- VPS ---
      vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./configuration.nix
          # Agenix for secrets
          inputs.agenix.nixosModules.default
          ({ config, pkgs, ... }: {
            virtualisation.vmVariant = {
              virtualisation.graphics = false;
              virtualisation.memorySize = 2048;
              virtualisation.cores = 2;

              virtualisation.forwardPorts = [
                { from = "host"; host.port = 2222; guest.port = 22; } # SSH
                { from = "host"; host.port = 8080; guest.port = 80; } # Web
                { from = "host"; host.port = 8443; guest.port = 443; } # Web (SSL)
                { from = "host"; host.port = 3000; guest.port = 3000; } # AdGuard
                { from = "host"; host.port = 3001; guest.port = 3001; } # Homepage
                { from = "host"; host.port = 3002; guest.port = 3002; } # Glance
                { from = "host"; host.port = 8001; guest.port = 8000; } # Vaultwarden
              ];

              # Use a dummy key for the VM since it cannot decrypt the real secret
              networking.wireguard.interfaces.wg0.privateKeyFile = pkgs.lib.mkForce "${pkgs.writeText "dummy-wg-key" "YF5X5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q4="}";
            };
          })
        ];
      };
    };

    # Package to build a VM for local tests
    packages = forEachSystem ({ pkgs }: {
      vps-vm = self.nixosConfigurations.vps.config.system.build.vm;
    });

    devShells = forEachSystem ({ pkgs }: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          just
          ssh
          agenix.packages.${system}.default
        ];
      };
    });
  };
}