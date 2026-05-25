{pkgs, ...}: {
  # 1. Open the Gate (Firewall)
  networking.firewall.allowedTCPPorts = [25565];

  # 2. Safety Net (Swap) - Vital for modded MC on limited RAM
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 4096;
    }
  ];

  # 3. Server Definition
  services.minecraft-servers = {
    enable = true;
    eula = true;

    servers = {
      fabric-server = {
        enable = true;
        autoStart = false;
        # Use jre_headless directly on the Fabric package
        package = pkgs.fabricServers.fabric-26_1_2.override {
          jre_headless = pkgs.jdk25_headless;
        };
        # RAM tuning:
        jvmOpts = "-Xms4G -Xmx4G -XX:+UseG1GC";

        serverProperties = {
          server-port = 25565;

          # --- SECURITY ---
          white-list = true;
          enforce-whitelist = true;
          online-mode = true; # Strict auth
          enable-rcon = false; # No remote console backdoor

          # --- GAMEPLAY ---
          difficulty = "hard";
          gamemode = "survival";
          view-distance = 10; # Keep low, let Distant Horizons handle visuals
          simulation-distance = 10;
          max-players = 10;
          motd = "Sanctuary";
        };

        # Declarative whitelist
        files."whitelist.json".value = [
          {
            name = "CartonBrutal";
            uuid = "9e761732-0263-41bd-93d2-2defd746816e";
          }
          # {
          #   name = "FriendsUsername";
          #   uuid = "friends-minecraft-uuid";
          # }
        ];

        # Mods (Local Directory Method)
        symlinks = {
          "mods" = ./mods;
        };
      };
    };
  };

  # 4. Scripts for easy management (sudo-compatible)
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "mc-start" "exec systemctl start minecraft-server-fabric-server")
    (pkgs.writeShellScriptBin "mc-stop" "exec systemctl stop minecraft-server-fabric-server")
    (pkgs.writeShellScriptBin "mc-console" "exec nix-minecraft-console fabric-server")
  ];
}
