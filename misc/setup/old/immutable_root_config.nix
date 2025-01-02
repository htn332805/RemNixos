{ config, lib, pkgs, ... }:
{
  # Rollback root dataset on each boot
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r vmpool/local/root@blank
  '';

  # Example persistent state configurations
  
  # Wireguard private key persistence
  networking.wireguard.interfaces.wg0 = {
    generatePrivateKeyFile = true;
    privateKeyFile = "/persist/etc/wireguard/wg0";
  };
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.kernelPackages = pkgs.zfs.latestCompatibleLinuxPackages;
  networking.hostname="hainixos";
  networking.hostId="12345678";
  time.timeZone = "America/Los_Angeles"; 
  #boot.loader.systemd-boot.enable = true;
  #boot.zfs = {
  #  forceImport = {
  #    enable = true;
  #    # Optional: specify additional import options
  #    pool = "vmpool";  # Specify your ZFS pool name if needed
  #  };
  #};
  # NetworkManager connections persistence
  
  etc."NetworkManager/system-connections" = {
    source = "/persist/etc/NetworkManager/system-connections/";
  };

  # SSH host keys persistence
  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/persist/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  #using systemd tmpfiles to create symbolic link
  systemd.tmpfiles.rules = [
 	"L /var/lib/bluetooth - - - - /persist/var/lib/bluetooth"
	"L /var/lib/acme - - - - /persist/var/lib/acme"
  ];
}
