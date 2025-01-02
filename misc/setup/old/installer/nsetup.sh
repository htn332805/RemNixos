#!/bin/bash

set -e

# Function to print messages
print_message() {
    echo "===> $1"
}

# Function to check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root" >&2
        exit 1
    fi
}

# Function to partition the disk
partition_disk() {
    local disk=$1
    print_message "Partitioning disk $disk"
    
    parted -s $disk mklabel gpt
    parted -s $disk mkpart ESP fat32 3MiB 1GiB
    parted -s $disk set 1 boot on
    parted -s $disk mkpart primary 1MiB 3MiB
    parted -s $disk set 2 bios_grub on
    #parted -s $disk mkpart ESP fat32 3MiB 1GiB
    #parted -s $disk set 2 boot on
    parted -s $disk mkpart primary 1GiB 100%
    mkfs.fat -F 32 -n ESP $disk"1" 
}

# Function to create ZFS pool and datasets
create_zfs_pool() {
    local disk=$1
    print_message "Creating ZFS pool and datasets"
    
    zpool create -f -o ashift=12 -O acltype=posixacl -O xattr=sa -O compression=lz4 -O normalization=formD rpool ${disk}3
    zfs create -o mountpoint=none rpool/root
    zfs create -o mountpoint=legacy rpool/root/nixos
    zfs create -o mountpoint=legacy rpool/home
    zfs snapshot rpool/root/nixos@blank
}

# Function to mount filesystems
mount_filesystems() {
    print_message "Mounting filesystems"
    
    mount -t zfs rpool/root/nixos /mnt
    mkdir -p /mnt/home
    mount -t zfs rpool/home /mnt/home
    mkdir -p /mnt/boot
    mount /dev/disk/by-partlabel/ESP /mnt/boot
}

# Function to generate NixOS configuration
generate_nixos_config() {
    print_message "Generating NixOS configuration"
    
    nixos-generate-config --root /mnt
    
    cat <<EOF >> /mnt/etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot loader
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.extraEntries = ''
    menuentry "rEFInd" {
      insmod part_gpt
      insmod fat
      insmod search_fs_uuid
      insmod chain
      search --fs-uuid --set=root XXXX-XXXX
      chainloader /EFI/refind/refind_x64.efi
    }
  '';

  # ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.requestEncryptionCredentials = true;

  # Networking
  networking.hostName = "nixos-zfs";
  networking.networkmanager.enable = true;

  # Time zone
  time.timeZone = "UTC";

  # Impermanence
  environment.persistence."/persist" = {
    directories = [
      "/etc/nixos"
      "/var/log"
      "/var/lib"
    ];
    files = [
      "/etc/machine-id"
    ];
  };

  # XRDP
  services.xrdp = {
    enable = true;
    defaultWindowManager = "x11vnc";
  };

  # Nginx
  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      root = "/var/www/localhost";
      locations."/" = {
        index = "index.html";
      };
    };
  };

  # NFS Server
  services.nfs.server = {
    enable = true;
    exports = ''
      /exports 192.168.1.0/24(rw,sync,no_subtree_check)
    '';
  };

  # ATFTP
  services.atftpd = {
    enable = true;
    root = "/srv/tftp";
  };

  # DNSMasq
  services.dnsmasq = {
    enable = true;
    extraConfig = ''
      dhcp-range=192.168.1.50,192.168.1.150,12h
      enable-tftp
      tftp-root=/srv/tftp
      dhcp-boot=pxelinux.0
    '';
  };

  # MariaDB
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  # JupyterLab
  services.jupyterlab = {
    enable = true;
    password = "your-hashed-password-here";
  };

  # Window Managers
  services.xserver = {
    enable = true;
    displayManager.defaultSession = "none+qtile";
    windowManager = {
      qtile.enable = true;
      dwm.enable = true;
      i3.enable = true;
    };
    desktopManager.xfce.enable = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    htop tmux screen nload git tree firefox chromium
    gnumeric wget curl neovim emacs nb
    python3Packages.dash python3Packages.matplotlib python3Packages.plotly
    python3Packages.pyvisa python3Packages.pyvisa-py python3Packages.pyusb
    python3Packages.zeroconf python3Packages.psutil
  ];

  # User configuration
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "dialout" ];
    initialPassword = "hai";
  };

  # USB access
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", MODE="0666"
  '';

  # WebSocket server
  services.websockify = {
    enable = true;
    sslCert = "/path/to/your/cert.pem";
    sslKey = "/path/to/your/key.pem";
  };

  # Vim and Neovim configuration
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    configure = {
      customRC = ''
        " Your custom Vim/Neovim configuration here
      '';
      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [ vim-airline vim-airline-themes vim-nix ];
      };
    };
  };

  # System-wide configuration
  system.stateVersion = "23.05";
}
EOF
}

# Function to install NixOS
install_nixos() {
    print_message "Installing NixOS"
    nixos-install -v --no-root-passwd
}

# Main script
check_root

read -p "Enter the disk to install NixOS on (e.g., /dev/sda): " DISK

partition_disk $DISK
create_zfs_pool $DISK
mount_filesystems
generate_nixos_config
cp -vf ./configuration.nix /mnt/etc/nixos
install_nixos

print_message "NixOS installation complete. Please reboot the system."
