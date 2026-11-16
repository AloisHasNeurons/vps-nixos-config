{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.minecraft;
in {
  # Off by default: the server is kept for later but not deployed (its two JDKs
  # alone add ~1.4 GB to every system generation). The `minecraft-eval` flake
  # check still evaluates it with enable = true, so it doesn't rot.
  #
  # Before re-enabling: /srv/minecraft (the world) is NOT in the restic backup,
  # add it to `paths` in modules/services/backup.nix. Also add 25565 back to the
  # allowed ports in tests/security.nix.
  options.my.minecraft.enable = lib.mkEnableOption "the Fabric Minecraft server";

  config = lib.mkIf cfg.enable {
    # Open the Gate (Firewall)
    networking.firewall.allowedTCPPorts = [25565];

    # Server Definition
    services.minecraft-servers = {
      enable = true;
      eula = true;

      servers = {
        fabric-server = {
          enable = true;
          autoStart = false;

          # Disable hibernation
          serverProperties.enable-status = true;

          # Use jre_headless directly on the Fabric package
          package = pkgs.fabricServers.fabric-26_1_2.override {
            jre_headless = pkgs.jdk25_headless;
          };
          # RAM tuning:
          jvmOpts = "-Xms1G -Xmx4G -XX:+UseG1GC";

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
            motd = "Serveur trop cool d'Aloïs avec Distant Horizons et Tectonic";
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

          # Declarative operators
          files."ops.json".value = [
            {
              name = "CartonBrutal";
              uuid = "9e761732-0263-41bd-93d2-2defd746816e";
              level = 4;
              bypassesPlayerLimit = true;
            }
          ];

          # Link each mod individually so Fabric sees a normal directory
          symlinks = builtins.listToAttrs (
            map (mod: {
              name = "mods/${mod.name}";
              value = pkgs.fetchurl {inherit (mod) name url hash;};
            }) (import ./mods.nix)
          );
        };
      };
    };

    # 4. Scripts for easy management (sudo-compatible)
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "mc-start" "exec systemctl start minecraft-server-fabric-server")
      (pkgs.writeShellScriptBin "mc-stop" "exec systemctl stop minecraft-server-fabric-server")
      (pkgs.writeShellScriptBin "mc-console" "nix-shell -p tmux --run 'sudo -u minecraft TERM=xterm-256color tmux -S /run/minecraft/fabric-server.sock attach'")
    ];
  };
}
