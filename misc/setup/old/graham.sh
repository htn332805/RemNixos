#!/usr/bin/env bash

# NixOS Immutable Infrastructure Setup Script
# Version: 1.0
# Author: Inspired by NixOS Immutable Infrastructure Approach

set -euo pipefail

# Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Utility functions
print_header() {
    echo -e "${GREEN}==== $1 ====${NC}"
}

print_step() {
    echo -e "${YELLOW}-> $1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

# Validate ZFS availability
validate_zfs() {
    print_header "Checking ZFS Availability"
    if ! command -v zfs &> /dev/null; then
        print_error "ZFS is not installed. Please install ZFS first."
    fi
}
# Partition disk for ZFS with GRUB BIOS partition
partition_disk() {
    print_header "Disk Partitioning"
    read -p "Enter the disk to partition (e.g., /dev/sda): " DISK

    # Validate disk exists
    if [ ! -b "$DISK" ]; then
        print_error "Disk $DISK does not exist."
    fi

    print_step "Creating GPT partition table"
    parted "$DISK" -- mklabel gpt

    print_step "Creating boot partition (512MB)"
    parted "$DISK" -- mkpart ESP fat32 1MB 512MB
    parted "$DISK" -- set 1 esp on

    print_step "Creating GRUB BIOS partition (8MB)"
    parted "$DISK" -- mkpart grub_bios 512MB 520MB
    parted "$DISK" -- set 2 bios_grub on

    print_step "Creating ZFS partition"
    parted "$DISK" -- mkpart primary ext4  520MB 100%
    mkfs.vfat -F32 -n ESP "${DISK}1"
    echo -e "${GREEN}Disk $DISK partitioned successfully with GRUB BIOS partition.${NC}"
}

# Create ZFS pools and datasets
create_zfs_structure() {
    print_header "Creating ZFS Datasets"
    
    # Prompt for ZFS pool name
    read -p "Enter ZFS pool name (default: rpool): " POOL
    POOL=${POOL:-rpool}

    # Create ZFS pool
    zpool create -f -o ashift=12 -O acltype=posixacl -O compression=lz4 -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa -O atime=off -o autotrim=on -o compatibility=openzfs-2.1-linux -m none "$POOL" "${DISK}3"

    # Create datasets
    print_step "Creating root dataset"
    zfs create -p -o mountpoint=legacy "$POOL/local/root"
    zfs snapshot "$POOL/local/root@blank"

    print_step "Creating /nix dataset"
    zfs create -p -o mountpoint=legacy "$POOL/local/nix"

    print_step "Creating /home dataset"
    zfs create -p -o mountpoint=legacy "$POOL/safe/home"

    print_step "Creating /persist dataset"
    zfs create -p -o mountpoint=legacy "$POOL/safe/persist"

    echo -e "${GREEN}ZFS datasets created successfully.${NC}"
}

# Generate NixOS configuration snippet
generate_nixos_config() {
    print_header "Generating NixOS Configuration Snippet"
    
    cat << EOF > /tmp/immutable_root_config.nix
{ config, lib, pkgs, ...}:

{
  # Rollback root dataset on each boot
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r $POOL/local/root@blank
  '';

  # Example persistent state configurations
  boot.supportedFilesystems = [ "zfs"  "ext4"  "btrfs"  "xfs"  "ntfs"  "vfat"  "exfat"  "hfs"  "hfsplus" "ext2" "ext3" "squashfs"];
  boot.loader.systemd-boot.enable = true;
  boot.loader.grub.device = "${DISK}";
  boot.loader.grub.useOSProber = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.kernelPackages = pkgs.zfs.latestCompatibleLinuxPackages;
  networking.hostName="hainixos";
  networking.hostId="12345678";
  time.timeZone = "America/Los_Angeles"
  # Wireguard private key persistence
  networking.wireguard.interfaces.wg0 = {
    generatePrivateKeyFile = true;
    privateKeyFile = "/persist/etc/wireguard/wg0";
  };
  #boot.zfs = {
  #  forceImport = {
  #    enable = true;
  #    # Optional: specify additional import options
  #    pool = "$POOL";  # Specify your ZFS pool name if needed
  #  };
  #};
  # NetworkManager connections persistence
  environment.etc."NetworkManager/system-connections" = {
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
	"L /etc/xrdp - - - - /persist/etc/xrdp"
        "L /etc/nixos - - - - /persist/etc/nixos"
  ];
}
EOF

    echo -e "${GREEN}NixOS configuration snippet saved to /tmp/immutable_root_config.nix${NC}"
    echo -e "${YELLOW}Note: You'll need to include this in your main configuration.nix${NC}"
}
# Mount ZFS datasets for NixOS installation
mount_zfs_datasets() {
    print_header "Mounting ZFS Datasets for NixOS Installation"

    # Prompt for mount point
    read -p "Enter the base mount point for installation (default: /mnt): " MOUNT_BASE
    MOUNT_BASE=${MOUNT_BASE:-/mnt}

    # Ensure mount base directory exists
    mkdir -p "$MOUNT_BASE"

    # Mount root dataset
    print_step "Mounting root dataset"
    mkdir -p "$MOUNT_BASE"
    mount -t zfs "$POOL/local/root" "$MOUNT_BASE"

    # Mount /boot partition
    print_step "Mounting boot partition"
    mkdir -p "$MOUNT_BASE/boot"
    mount "$DISK"1 "$MOUNT_BASE/boot"

    # Mount /nix dataset
    print_step "Mounting /nix dataset"
    mkdir -p "$MOUNT_BASE/nix"
    mount -t zfs "$POOL/local/nix" "$MOUNT_BASE/nix"

    # Mount /home dataset
    print_step "Mounting /home dataset"
    mkdir -p "$MOUNT_BASE/home"
    mount -t zfs "$POOL/safe/home" "$MOUNT_BASE/home"

    # Mount /persist dataset
    print_step "Mounting /persist dataset"
    mkdir -p "$MOUNT_BASE/persist"
    mount -t zfs "$POOL/safe/persist" "$MOUNT_BASE/persist"

    # Display mounted filesystems
    print_header "Mounted Filesystems"
    df -h "$MOUNT_BASE"

    echo -e "${GREEN}ZFS datasets mounted successfully for NixOS installation.${NC}"
}


# Modify main() to include the new mounting function
main() {
    print_header "NixOS Immutable Infrastructure Setup"
    
    validate_zfs
    partition_disk
    create_zfs_structure
    mount_zfs_datasets  # Add this line to include dataset mounting
    generate_nixos_config
    
	mkdir -p /persist/etc/wireguard/
	mkdir -p /persist/etc/xrdp
	mkdir -p /persist/etc/nixos
	mkdir -p /persist/etc/NetworkManager/system-connections
	mkdir -p /persist/var/lib/bluetooth
	mkdir -p /persist/etc/ssh
	mkdir -p /persist/var/lib/acme
    echo -e "${GREEN}Setup complete! Next steps:
1. Run nixos-generate-config --root $MOUNT_BASE
2. Include the generated configuration snippet in configuration.nix
3. Complete NixOS installation${NC}"
}

# Run the script
main
