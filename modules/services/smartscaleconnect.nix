{config, ...}: {
  # Agenix secret decryption for SmartScaleConnect configuration
  age.secrets.scaleconnect-yaml = {
    file = ../../secrets/scaleconnect-yaml.age;
  };

  # Secure directory on host to persist OAuth credentials (scaleconnect.json)
  systemd.tmpfiles.rules = [
    "d /var/lib/smartscaleconnect 0700 root root -"
  ];

  # Run SmartScaleConnect container
  virtualisation.oci-containers.containers.smartscaleconnect = {
    image = "ghcr.io/alexxit/smartscaleconnect/amd64:latest";
    autoStart = true;
    volumes = [
      "/var/lib/smartscaleconnect:/app"
      "${config.age.secrets.scaleconnect-yaml.path}:/app/scaleconnect.yaml:ro"
    ];
    # Run in daemon mode, syncing every 4 hours
    cmd = ["-r" "4h"];
  };

  # Hook up failures to Gotify push notifications
  systemd.services.podman-smartscaleconnect.unitConfig.OnFailure = "notify-failure@%n.service";
}
