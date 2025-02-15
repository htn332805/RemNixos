{ lib, disks ? null, zpools ? null, ... }:

let
  devices = {
    disk = {
      disk1 = {
        type = "disk";
        #device = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBafedd100-67286476";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
	    BIOS = {
		size = "1M";
		type = "EF02";
	    };
            ESP = {
              size = "256M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          }; # partitions
        }; # content
      }; # disk1
      #disk2 = {
      #  type = "disk";
      #  device = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBc909afa2-42881324";
      #  content = {
      #    type = "gpt";
      #    partitions = {
      #      ESP = {
      #        size = "256M";
      #        type = "EF00";
      #        content = {
      #          type = "filesystem";
      #          format = "vfat";
      #          mountpoint = "/boot2";
      #        };
      #      };
      #      zfs = {
      #        size = "100%";
      #        content = {
      #          type = "zfs";
      #          pool = "rpool";
      #        };
      #      };
      #    }; # partitions
      #  }; # content
      #}; # disk2
    }; # disk
    zpool = {
      rpool = {
        type = "zpool";
        #mode = "mirror";
        rootFsOptions = {
          acltype = "posixacl";
          dnodesize = "auto";
          canmount = "off";
          xattr = "sa";
          relatime = "on";
          normalization = "formD";
          mountpoint = "none";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          # keylocation = "prompt";
          keylocation = "file:///tmp/pass-zpool-rpool";
          compression = "lz4";
          "com.sun:auto-snapshot" = "false";
        };
        postCreateHook = ''
          zfs set keylocation="prompt" rpool
        '';
        options = {
          ashift = "12";
          autotrim = "on";
        };

        datasets = {
          local = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          safe = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "local/reserved" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              reservation = "5GiB";
            };
          };
          "local/root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
            postCreateHook = ''
              zfs snapshot rpool/local/root@blank
            '';
          };
          "local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              atime = "off";
              canmount = "on";
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "true";
            };
          };
          "local/log" = {
            type = "zfs_fs";
            mountpoint = "/var/log";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "true";
            };
          };
          "safe/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "true";
            };
          };
          "safe/persistent" = {
            type = "zfs_fs";
            mountpoint = "/persistent";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "true";
            };
          };
        }; # datasets
      }; # rpool
    }; # zpool
  }; # devices
in
{
  disko.devices = {
    disk = lib.filterAttrs
      (n: v: disks == null || builtins.elem n disks)
      devices.disk;

    zpool = lib.filterAttrs
      (n: v: zpools == null || builtins.elem n zpools)
      devices.zpool;
  };
}
