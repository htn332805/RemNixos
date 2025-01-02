#!/bin/bash

set -e

# Function to print colored output
print_color() {
    COLOR=$1
    MESSAGE=$2
    echo -e "\e[${COLOR}m${MESSAGE}\e[0m"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    print_color "31" "This script must be run as root"
    exit 1
fi

# Check for required tools
for cmd in zpool zfs sgdisk mkfs.vfat mkswap; do
    if ! command_exists "$cmd"; then
        print_color "31" "Required command '$cmd' not found. Please install it and try again."
        exit 1
    fi
done

# Prompt for disk selection
print_color "36" "Available disks:"
lsblk -d -n -p -o NAME,SIZE,MODEL
echo
read -p "Enter the disk to use (e.g., /dev/sda): " DISK

# Confirm disk selection
read -p "Are you sure you want to use $DISK? This will erase all data on the disk. (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_color "31" "Operation cancelled."
    exit 1
fi

# Wipe the disk
print_color "33" "Wiping disk $DISK..."
sgdisk --zap-all "$DISK"

# Create partitions
print_color "33" "Creating partitions..."
sgdisk -n 1:0:+512M -t 1:EF00 -c 1:"EFI System" \
       -n 2:0:+512M -t 2:EF02 -c 2:"BIOS Boot" \
       -n 3:0:+4G -t 3:8200 -c 3:"Linux Swap" \
       -n 4:0:0 -t 4:BF00 -c 4:"ZFS" \
       "$DISK"

# Create file systems
print_color "33" "Creating file systems..."
mkfs.vfat -F 32 -n EFI "${DISK}1"
mkswap -L swap "${DISK}3"
swapon "${DISK}3"

# Generate hostid
HOSTID=$(head -c 8 /etc/machine-id)

# Create ZFS pool and datasets
print_color "33" "Creating ZFS pool and datasets..."
zpool create -f -o ashift=12 -O acltype=posixacl -O compression=lz4 -O dnodesize=auto \
    -O normalization=formD -O relatime=on -O xattr=sa -O mountpoint=none \
    -R /mnt rpool "${DISK}4"

zfs create -o mountpoint=none rpool/root
zfs create -o mountpoint=legacy rpool/root/nixos
zfs create -o mountpoint=legacy rpool/home

# Mount file systems
print_color "33" "Mounting file systems..."
mount -t zfs rpool/root/nixos /mnt
mkdir /mnt/home
mount -t zfs rpool/home /mnt/home
mkdir /mnt/boot
mount "${DISK}1" /mnt/boot

# Generate NixOS configuration
print_color "33" "Generating NixOS configuration..."
nixos-generate-config --root /mnt

# Modify configuration for ZFS and impermanence
print_color "33" "Modifying NixOS configuration..."
cat << EOF >> /mnt/etc/nixos/configuration.nix

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/disk/by-id";
  networking.hostId = "${HOSTID}";
  
  # Impermanence
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r rpool/root/nixos@blank
  '';

  fileSystems."/" = { 
    device = "rpool/root/nixos";
    fsType = "zfs";
  };

  fileSystems."/home" = { 
    device = "rpool/home";
    fsType = "zfs";
  };

  fileSystems."/boot" = { 
    device = "${DISK}1";
    fsType = "vfat";
  };

  swapDevices = [ { device = "${DISK}3"; } ];

  boot.loader.grub = {
    enable = true;
    version = 2;
    devices = [ "${DISK}" ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
EOF

# Create a blank snapshot for rollback
print_color "33" "Creating blank snapshot for rollback..."
zfs snapshot rpool/root/nixos@blank

print_color "32" "ZFS root setup complete!"
print_color "32" "You can now customize your NixOS configuration and run 'nixos-install' to complete the installation."
print_color "32" "After installation, the system will roll back to the blank snapshot on each reboot."
print_color "32" "Remember to create persistent datasets for data you want to keep across reboots."
