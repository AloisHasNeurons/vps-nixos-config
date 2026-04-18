{pkgs, ...}: {
  # Kernel hardening
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # AppArmor
  security.apparmor = {
    enable = true;
    packages = [pkgs.apparmor-utils];
  };

  # Audit
  security.audit.enable = true;
  security.auditd.enable = true;
  security.audit.rules = [
    # 1. Log all system call executions
    "-a exit,always -F arch=b64 -S execve"

    # 2. Record modifications to user/group information
    "-w /etc/group -p wa -k identity"
    "-w /etc/passwd -p wa -k identity"
    "-w /etc/shadow -p wa -k identity"
    "-w /etc/sudoers -p wa -k identity"

    # 3. Monitor unauthorized access attempts (failed reads/writes due to permissions)
    "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -k access"
    "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -k access"

    # 4. Monitor use of elevated privileges
    "-a always,exit -F arch=b64 -S setuid -S setgid -S setreuid -S setregid -k privileged"

    # 5. Monitor modifications to network configurations
    "-w /etc/hosts -p wa -k network_mod"
    "-w /etc/resolv.conf -p wa -k network_mod"

    # 6. Monitor time changes (often used by attackers to obfuscate log timelines)
    "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k time-change"
  ];

  # Sysctl hardening
  boot.kernel.sysctl = {
    # Hide kernel pointers
    "kernel.kptr_restrict" = 2;

    # Restrict dmesg usage
    "kernel.dmesg_restrict" = 1;

    # Networking hardening
    "net.ipv4.conf.all.log_martians" = true;
    "net.ipv4.conf.default.log_martians" = true;
    "net.ipv4.conf.all.accept_redirects" = false;
    "net.ipv4.conf.default.accept_redirects" = false;
    "net.ipv6.conf.all.accept_redirects" = false;
    "net.ipv6.conf.default.accept_redirects" = false;
    "net.ipv4.conf.all.send_redirects" = false;
    "net.ipv4.conf.default.send_redirects" = false;

    # TCP hardening
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_rfc1337" = 1; # Protect against time-wait assassination

    # TCP Optimization
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # TCP MTU Probing - checking for black holes
    "net.ipv4.tcp_mtu_probing" = 1;

    # Socket buffer tuning for WireGuard throughput
    "net.core.rmem_max" = 2500000;
    "net.core.wmem_max" = 2500000;
  };
}
