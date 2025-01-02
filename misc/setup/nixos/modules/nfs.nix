{ config, lib, pkgs, ... }:

let
  nfsLogFile = "/var/log/nfs.log";
in
{
  # Enable NFS server
  services.nfs.server = {
    enable = true;
    exports = ''
      /srv/nfs 192.168.1.0/24(rw,sync,no_subtree_check,crossmnt,fsid=0)
    '';
  };

  # Open firewall ports for NFS
  networking.firewall.allowedTCPPorts = [ 2049 ];
  networking.firewall.allowedUDPPorts = [ 2049 ];

  # Configure NFS settings with logging
  services.nfs.settings = {
    nfsd = {
      vers4 = true;
      "vers4.0" = true;
      "vers4.1" = true;
      "vers4.2" = true;
      udp = false;
      tcp = true;
    };
    # Enable NFS server logging
    general = {
      "log-file" = nfsLogFile;
      "log-level" = "all";
    };
  };

  # Ensure log file exists and has correct permissions
  systemd.tmpfiles.rules = [
    "f ${nfsLogFile} 0640 root root -"
  ];

  # Install necessary packages and add custom script
  environment.systemPackages = with pkgs; [
    nfs-utils
    (writeScriptBin "view-nfs-logs" ''
      #!${pkgs.bash}/bin/bash
      if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root" >&2
        exit 1
      fi
      tail -f ${nfsLogFile}
    '')
  ];

  # Rotate NFS logs
  services.logrotate = {
    enable = true;
    settings = {
      ${nfsLogFile} = {
        rotate = 7;
        weekly = true;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        postrotate = ''
          systemctl reload nfs-server.service
        '';
      };
    };
  };
}


