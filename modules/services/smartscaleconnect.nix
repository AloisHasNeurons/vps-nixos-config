{
  config,
  pkgs,
  ...
}: let
  # Native compilation of SmartScaleConnect Go program from source
  smartscaleconnect-pkg = pkgs.buildGoModule rec {
    pname = "smartscaleconnect";
    version = "0.4.2";

    src = pkgs.fetchFromGitHub {
      owner = "AlexxIT";
      repo = "SmartScaleConnect";
      rev = "v${version}";
      hash = "sha256-Hv1qT13Hgv3YkUVd0m4Qp0H827pXAgBlUflBIq3lUTc=";
    };

    # Set the correct vendorHash computed by Nix
    vendorHash = "sha256-63e4EtWB13Ou4S5vhr0vKTVrKMPZBwtJ6BKk+syMVZ8=";
  };
in {
  # Agenix secret decryption for SmartScaleConnect configuration
  age.secrets.scaleconnect-yaml = {
    file = ../../secrets/scaleconnect-yaml.age;
  };

  # Secure directory on host to persist OAuth credentials (scaleconnect.json)
  systemd.tmpfiles.rules = [
    "d /var/lib/smartscaleconnect 0700 root root -"
  ];

  # Run SmartScaleConnect as a native systemd daemon service
  systemd.services.smartscaleconnect = {
    description = "SmartScaleConnect sync daemon";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      ExecStartPre = pkgs.writeShellScript "smartscaleconnect-pre" ''
        # Copy the decrypted agenix config to our persistent state dir
        cp -f ${config.age.secrets.scaleconnect-yaml.path} /var/lib/smartscaleconnect/scaleconnect.yaml
        chmod 600 /var/lib/smartscaleconnect/scaleconnect.yaml
      '';
      ExecStart = "${smartscaleconnect-pkg}/bin/SmartScaleConnect -c /var/lib/smartscaleconnect/scaleconnect.yaml -r 4h";
      Restart = "always";
      RestartSec = "10s";
      WorkingDirectory = "/var/lib/smartscaleconnect";
    };

    # Hook up failures to Gotify push notifications
    unitConfig.OnFailure = "notify-failure@%n.service";
  };
}
