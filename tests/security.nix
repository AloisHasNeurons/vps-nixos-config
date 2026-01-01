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
    
    # 1. Run a generic scan (Top 1000 ports) to check for ANY open ports
    # This ensures forward compatibility: if you add a new service and accidentally expose it, this test will fail.
    scan_output = scanner.succeed(f"nmap {target_ip} --open")
    print(f"Scan Output:\n{scan_output}")
    
    # 2. Parse open TCP ports
    import re
    # Matches lines like "80/tcp open http"
    open_ports = re.findall(r"(\d+)/tcp\s+open", scan_output)
    
    # 3. Define the Whitelist (Publicly Allowed Ports)
    # 22: SSH
    # 80: HTTP (ACME/Redirect)
    # 443: HTTPS
    allowed_ports = ['22', '80', '443']
    
    # 4. Verify
    unexpected_ports = [p for p in open_ports if p not in allowed_ports]
    
    if unexpected_ports:
        raise Exception(f"SECURITY ALERT: Found unexpected open TCP ports: {unexpected_ports}. Check your firewall!")
    
    # Verify minimal expected ports are actually open (sanity check)
    if '22' not in open_ports:
         raise Exception("sanity check failed: SSH (22) is not open?")
    if '80' not in open_ports:
         print("Warning: Port 80 is not open (maybe Nginx not ready or config changed?)")

    print("Success: Public firewall is clean. No unexpected ports exposed.")
  '';
}
