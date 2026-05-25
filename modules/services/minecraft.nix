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
        package = pkgs.fabricServers.fabric-26_1_2;

        # RAM TUNING:
        # -Xms3G: Start low to respect Immich/System
        # -Xmx4G: Cap at 4GB to prevent OOM Kills
        # jvmOpts = "-Xms3G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1";

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
# https://cdn.modrinth.com/data/P7dR8mSH/versions/BLz7ETCw/fabric-api-0.149.1%2B26.1.2.jar
# https://cdn.modrinth.com/data/gvQqBUqZ/versions/R7MxYvuW/lithium-fabric-0.24.2%2Bmc26.1.2.jar
# https://cdn.modrinth.com/data/uXXizFIs/versions/d5ddUdiB/ferritecore-9.0.0-fabric.jar
# https://cdn.modrinth.com/data/hasdd01q/versions/QWyo5TsS/noisium-fabric-2.8.4%2Bmc26.1-pre-2.jar
# https://cdn.modrinth.com/data/lWDHr9jE/versions/jL2ZsTzx/tectonic-3.0.22-fabric-26.1.jar
# https://cdn.modrinth.com/data/8oi3bsk5/versions/FCzSjHeG/Terralith_26.1_v2.6.2_Fabric.jar
# https://cdn.modrinth.com/data/uCdwusMi/versions/FJrLlu3p/DistantHorizons-3.0.3-b-26.1.2-fabric-neoforge.jar

