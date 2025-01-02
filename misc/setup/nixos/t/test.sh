#!/usr/bin/env bash

#
# NixOS install script synthesized from:
#
#   - Erase Your Darlings (https://grahamc.com/blog/erase-your-darlings)
#   - ZFS Datasets for NixOS (https://grahamc.com/blog/nixos-on-zfs)
#   - NixOS Manual (https://nixos.org/nixos/manual/)
#
# It expects the name of the block device (e.g. 'sda') to partition
# and install NixOS on and an authorized public ssh key to log in as
# 'root' remotely. The script must also be executed as root.
#
# Example: `sudo ./install.sh sde "ssh-rsa AAAAB..."`
#

set -euo pipefail

################################################################################

export COLOR_RESET="\033[0m"
export RED_BG="\033[41m"
export BLUE_BG="\033[44m"

function err {
    echo -e "${RED_BG}$1${COLOR_RESET}"
}

function info {
    echo -e "${BLUE_BG}$1${COLOR_RESET}"
}

################################################################################

export DISK=$1
export AUTHORIZED_SSH_KEY=$2

if ! [[ -v DISK ]]; then
    err "Missing argument. Expected block device name, e.g. 'sda'"
    exit 1
fi

export DISK_PATH="/dev/${DISK}"

if ! [[ -b "$DISK_PATH" ]]; then
    err "Invalid argument: '${DISK_PATH}' is not a block special file"
    exit 1
fi

if ! [[ -v AUTHORIZED_SSH_KEY ]]; then
    err "Missing argument. Expected public SSH key, e.g. 'ssh-rsa AAAAB...'"
    exit 1
fi

if [[ "$EUID" > 0 ]]; then
    err "Must run as root"
    exit 1
fi

export ZFS_POOL="nixpool"

# ephemeral datasets
export ZFS_LOCAL="${ZFS_POOL}/local"
export ZFS_DS_ROOT="${ZFS_LOCAL}/root"
export ZFS_DS_NIX="${ZFS_LOCAL}/nix"

# persistent datasets
export ZFS_SAFE="${ZFS_POOL}/safe"
export ZFS_DS_HOME="${ZFS_SAFE}/home"
export ZFS_DS_PERSIST="${ZFS_SAFE}/persist"

export ZFS_BLANK_SNAPSHOT="${ZFS_DS_ROOT}@blank"

################################################################################

info "Running the UEFI (GPT) partitioning and formatting directions from the NixOS manual ..."
# Create a protective MBR and GPT table
parted "$DISK_PATH" -- mklabel gpt
# Create DISK_PART_BOOT as the first partition (ESP)
parted "$DISK_PATH" -- mkpart ESP fat32 1MiB 513MiB
parted "$DISK_PATH" -- set 1 boot on
# Create DISK_PART_BIOS as the second partition
parted "$DISK_PATH" -- mkpart primary 513MiB 521MiB
parted "$DISK_PATH" -- set 2 bios_grub on
# Create DISK_PART_ROOT as the third partition
parted "$DISK_PATH" -- mkpart primary 521MiB 100%
# Export partition variables
export DISK_PART_BOOT="${DISK_PATH}1"
export DISK_PART_BIOS="${DISK_PATH}2"
export DISK_PART_ROOT="${DISK_PATH}3"





#parted "$DISK_PATH" -- mklabel gpt
#parted "$DISK_PATH" -- mkpart primary 1MiB 9MiB
#parted "$DISK_PATH" -- set 1 bios_grub on
#parted "$DISK_PATH" -- mkpart ESP fat32 9MiB 521MiB
#parted "$DISK_PATH" -- set 2 boot on
#parted "$DISK_PATH" -- mkpart primary 521MiB 100%
#export DISK_PART_BIOS="${DISK_PATH}1"
#export DISK_PART_BOOT="${DISK_PATH}2"
#export DISK_PART_ROOT="${DISK_PATH}3"

info "Formatting boot partition ..."
mkfs.fat -F 32 -n EFI "$DISK_PART_BOOT"

info "Creating '$ZFS_POOL' ZFS pool for '$DISK_PART_ROOT' ..."
zpool create -f "$ZFS_POOL" "$DISK_PART_ROOT"

info "Enabling compression for '$ZFS_POOL' ZFS pool ..."
zfs set compression=on "$ZFS_POOL"

info "Creating '$ZFS_DS_ROOT' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_ROOT"

info "Configuring extended attributes setting for '$ZFS_DS_ROOT' ZFS dataset ..."
zfs set xattr=sa "$ZFS_DS_ROOT"

info "Configuring access control list setting for '$ZFS_DS_ROOT' ZFS dataset ..."
zfs set acltype=posixacl "$ZFS_DS_ROOT"

info "Creating '$ZFS_BLANK_SNAPSHOT' ZFS snapshot ..."
zfs snapshot "$ZFS_BLANK_SNAPSHOT"

info "Mounting '$ZFS_DS_ROOT' to /mnt ..."
mount -t zfs "$ZFS_DS_ROOT" /mnt

info "Mounting '$DISK_PART_BOOT' to /mnt/boot ..."
mkdir /mnt/efi
mount -t vfat "$DISK_PART_BOOT" /mnt/efi

info "Creating '$ZFS_DS_NIX' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_NIX"

info "Disabling access time setting for '$ZFS_DS_NIX' ZFS dataset ..."
zfs set atime=off "$ZFS_DS_NIX"

info "Mounting '$ZFS_DS_NIX' to /mnt/nix ..."
mkdir /mnt/nix
mount -t zfs "$ZFS_DS_NIX" /mnt/nix

info "Creating '$ZFS_DS_HOME' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_HOME"

info "Mounting '$ZFS_DS_HOME' to /mnt/home ..."
mkdir /mnt/home
mount -t zfs "$ZFS_DS_HOME" /mnt/home

info "Creating '$ZFS_DS_PERSIST' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_PERSIST"

info "Mounting '$ZFS_DS_PERSIST' to /mnt/persist ..."
mkdir /mnt/persist
mount -t zfs "$ZFS_DS_PERSIST" /mnt/persist

info "Permit ZFS auto-snapshots on ${ZFS_SAFE}/* datasets ..."
zfs set com.sun:auto-snapshot=true "$ZFS_DS_HOME"
zfs set com.sun:auto-snapshot=true "$ZFS_DS_PERSIST"

info "Creating persistent directory for host SSH keys ..."
mkdir -p /mnt/persist/etc/ssh

info "Generating NixOS configuration (/mnt/etc/nixos/*.nix) ..."
nixos-generate-config --root /mnt

info "Enter password for the root user ..."
ROOT_PASSWORD_HASH="$(mkpasswd -m sha-512 | sed 's/\$/\\$/g')"

info "Enter personal user name ..."
read USER_NAME

info "Enter password for '${USER_NAME}' user ..."
USER_PASSWORD_HASH="$(mkpasswd -m sha-512 | sed 's/\$/\\$/g')"

info "Moving generated hardware-configuration.nix to /persist/etc/nixos/ ..."
mkdir -p /mnt/persist/etc/nixos
mv /mnt/etc/nixos/hardware-configuration.nix /mnt/persist/etc/nixos/

info "Backing up the originally generated configuration.nix to /persist/etc/nixos/configuration.nix.original ..."
mv /mnt/etc/nixos/configuration.nix /mnt/persist/etc/nixos/configuration.nix.original

info "Backing up the this installer script to /persist/etc/nixos/install.sh.original ..."
cp "$0" /mnt/persist/etc/nixos/install.sh.original

info "Writing NixOS configuration to /persist/etc/nixos/ ..."
cat <<EOF > /mnt/persist/etc/nixos/packages.nix
{ config, pkgs, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    vim
    wget
    firefox
    git
  ];
}
EOF

cat <<EOF > /mnt/persist/etc/nixos/networking.nix
{ config, pkgs, ... }:

{
  networking = {
    hostName = "nixos";
    hostId = "$(head -c 8 /etc/machine-id)";
    networkmanager.enable = true;
  };
}
EOF

cat <<EOF > /mnt/persist/etc/nixos/users.nix
{ config, pkgs, ... }:

{
  # Define a user account
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "hai";
  };
}
EOF

cat <<EOF > /mnt/persist/etc/nixos/configuration.nix
{ config, pkgs, lib, ... }:
{
  imports =
    [ 
      ./hardware-configuration.nix
      ./users.nix
      ./networking.nix
      ./packages.nix
    ];

  # Use the systemd-boot EFI boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Set your time zone
  time.timeZone = "America/Los_Angeles";
  # Enable sound
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable the X11 windowing system
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  # System-wide environment variables
  environment.variables = {
    EDITOR = "vim";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "24.05";
}
EOF

info "Installing NixOS to /mnt ..."
ln -s /mnt/persist/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix
ln -s /mnt/persist/etc/nixos/users.nix /mnt/etc/nixos/users.nix
ln -s /mnt/persist/etc/nixos/networking.nix /mnt/etc/nixos/networking.nix
ln -s /mnt/persist/etc/nixos/packages.nix /mnt/etc/nixos/packages.nix
ln -s /mnt/persist/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix
#need to run sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz home-manager and  sudo nix-channel --update then add "home-manager=/nix/var/nix/profiles/per-user/root/channels/home-manager" to config file
#nixos-install -I "nixos-config=/mnt/persist/etc/nixos/configuration.nix" --no-root-passwd  # already prompted for and configured password
