{ config, pkgs, ... }:

{
# Use the systemd-boot EFI boot loader
  #boot.loader.systemd-boot.enable = true;
  #boot.loader.efi.canTouchEfiVariables = true;
  #boot.loader.efiSysMountPoint = '/efi'

  boot = {
    supportedFilesystems = [ "ext2" "ext3" "btrfs" "reiserfs" "jfs" "hfs+" "iso9660" "cpio" "affs" "zfs"  "ext4"  "btrfs"  "xfs"  "ntfs"  "vfat"  "exfat"  "hfs"  "hfsplus" ];
    loader = {
      efi = {
        #canTouchEfiVariables = true;
        canTouchEfiVariables = false;  #for BIOS
        efiSysMountPoint = "/boot";
      };    #end efi bracket
      grub = {
        enable = true;
	useOSProber = true;
        timeout = 45;
	version = 2;
        efiSupport = true;
	zfsSupport = true;
	forceInstall = true;
	efiInstallAsRemovable = true;
	extraFiles = {
  		"x86_64-efi/modinfo.sh" = "${pkgs.grub2}/lib/grub/x86_64-efi/modinfo.sh";
		};
        #device = "nodev";
	device =  "/dev/sda" ;
	extraEntries = ''
		menuentry "rEFInd" {
			insmod part_gpt
			insmod fat
			insmod chain
			search --no-floppy --fs-uuid --set=root F749-B102 
			chainloader /EFI/refind/refind_x64.efi
		}
	'';
	default = "rEFInd";
		}; #end grub bracket
    }; #end lloader
    zfs = {
      requestEncryptionCredentials = true;
      forceImportRoot = false;
    };
  };  #end boot bracket
}

