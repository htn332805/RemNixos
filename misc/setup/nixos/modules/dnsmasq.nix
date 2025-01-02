{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.customDnsmasq;
in {
  options.services.customDnsmasq = {
    enable = mkEnableOption "Custom Dnsmasq service";

    interface = mkOption {
      type = types.str;
      default = "enabcm6e4ei0";
      description = "Network interface to listen on";
    };

    dhcpRange = mkOption {
      type = types.str;
      default = "192.168.1.50,192.168.1.150,12h";
      description = "DHCP range and lease time";
    };

    pxeBootFile = mkOption {
      type = types.str;
      default = "pxelinux.0";
      description = "PXE boot file";
    };

    tftpRoot = mkOption {
      type = types.str;
      default = "/persist/var/lib/tftpboot";
      description = "TFTP root directory";
    };
  };

  config = mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      extraConfig = ''
        interface=${cfg.interface}
        dhcp-range=${cfg.dhcpRange}
        enable-tftp
        tftp-root=${cfg.tftpRoot}
        dhcp-boot=${cfg.pxeBootFile}
        log-dhcp
        log-queries
        log-facility=/persist/var/log/dnsmasq.log
      '';
    };

    systemd.services.dnsmasq = {
      serviceConfig = {
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.tftpRoot}"
          "${pkgs.coreutils}/bin/chown -R dnsmasq:dnsmasq ${cfg.tftpRoot}"
        ];
      };
    };

    networking.firewall = {
      allowedUDPPorts = [ 53 67 68 69 ];
      allowedTCPPorts = [ 53 ];
    };

    environment.systemPackages = [ pkgs.dnsmasq ];
  };
}
