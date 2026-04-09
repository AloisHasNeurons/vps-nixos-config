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
