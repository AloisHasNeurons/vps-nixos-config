{ pkgs, inputs, ... }:

pkgs.testers.nixosTest {
  name = "security-port-scan";
  
  # Python type checking doesn't know about dynamic machine names
  skipTypeCheck = true; 
  skipLint = true;
  
  nodes = {
    # The server node running our configuration
    server = { config, pkgs, ... }: {
      # Pass flake inputs to the module system
      _module.args.inputs = inputs;
      
      imports = [ 
        ../configuration.nix 
        ../disk-config.nix 
        inputs.agenix.nixosModules.default 
        inputs.disko.nixosModules.disko 
      ];

      # --- VM Specific Overrides (to make it bootable in test) ---
      
      # Dummy WireGuard key (since we can't decrypt real secrets)
      age.secrets.wireguard-private-key.file = pkgs.lib.mkForce (pkgs.writeText "dummy-wg" "YF5X5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q4=");
      
      # Mock interface for WireGuard to prevent startup failure
      networking.wireguard.interfaces.wg0.privateKeyFile = pkgs.lib.mkForce (toString (pkgs.writeText "dummy-wg" "YF5X5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q5Q5q4="));

      # Force hostname to be 'server' so the python script variable matches
      networking.hostName = pkgs.lib.mkForce "server";

      # Force standard VM settings
      virtualisation.memorySize = 2048;
      virtualisation.cores = 2;
      
      # Ensure network interfaces get IPs
      networking.useDHCP = true;
    };

    # The attacker/scanner node
    scanner = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.nmap ];
    };
  };

  testScript = { nodes, ... }: ''
    start_all()
    
    # Wait for server to be ready
    server.wait_for_unit("multi-user.target")
    server.wait_for_unit("sshd.service")
    
    # Wait for webserver to start listening
    server.wait_for_open_port(80)
    
    
    # Get the server's IP address dynamically (wait for DHCP)
    # Exclude 127.0.0.1 and look for non-lo interfaces
    target_ip = server.wait_until_succeeds("ip -4 addr show eth1 | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1").strip()
    
    # 1. Scan allowed ports (Should SUCCEED)
    # Port 80 (HTTP) 
    scanner.succeed(f"nmap -p 80 {target_ip} | grep open")
    # Port 22 (SSH)
    scanner.succeed(f"nmap -p 22 {target_ip} | grep open")
    
    # 2. Scan blocked ports (Should FAIL to find them open)
    # AdGuard (3000) should be blocked externally
    scanner.fail(f"nmap -p 3000 {target_ip} | grep open")
    # Vaultwarden (8000) should be blocked externally
    scanner.fail(f"nmap -p 8000 {target_ip} | grep open")
    # Homepage (3001) should be blocked externally
    scanner.fail(f"nmap -p 3001 {target_ip} | grep open")
    # Glance (3002) should be blocked externally
    scanner.fail(f"nmap -p 3002 {target_ip} | grep open")
  '';
}
