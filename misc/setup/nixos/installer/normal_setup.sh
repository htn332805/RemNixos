#!/bin/bash

set -e

# Function to print messages
print_message() {
    echo "=== $1 ==="
}

# Disk selection
print_message "Select disk for installation"
lsblk
read -p "Enter disk name (e.g. sda): " DISK
DISK="/dev/${DISK}"

# Partition the disk
print_message "Partitioning disk"
parted -s "${DISK}" -- mklabel gpt
parted -s "${DISK}" -- mkpart ESP fat32 1MiB 512MiB
parted -s "${DISK}" -- set 1 boot on
parted -s "${DISK}" -- mkpart primary 512MiB 513MiB
parted -s "${DISK}" -- set 2 bios_grub on
parted -s "${DISK}" -- mkpart primary 513MiB 100%

# Create ZFS pool
print_message "Creating ZFS pool"
zpool create -f rpool "${DISK}3"

# Create ZFS datasets
print_message "Creating ZFS datasets"
zfs create -o mountpoint=none rpool/root
zfs create -o mountpoint=legacy rpool/root/nixos
zfs create -o mountpoint=legacy rpool/home

# Mount filesystems
print_message "Mounting filesystems"
mount -t zfs rpool/root/nixos /mnt
mkdir /mnt/home
mount -t zfs rpool/home /mnt/home
mkdir /mnt/boot
mount "${DISK}1" /mnt/boot

# Generate NixOS configuration
print_message "Generating NixOS configuration"
nixos-generate-config --root /mnt

# Customize configuration
print_message "Customizing NixOS configuration"
cat <<EOF >> /mnt/etc/nixos/configuration.nix

  # Enable XRDP
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "startxfce4";

  # Enable X11VNC
  services.x11vnc = {
    enable = true;
    auth = "/home/nixos/.Xauthority";
    password = "your_password";
  };

  # Enable Nginx
  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      root = "/var/www/localhost";
    };
  };

  # Enable impermanence
  fileSystems."/persist" = {
    device = "rpool/persist";
    fsType = "zfs";
    options = [ "zfsutil" "X-mount.mkdir" ];
  };

  # Enable NFS server
  services.nfs.server.enable = true;

  # Enable ATFTP
  services.atftpd.enable = true;

  # Enable DNSMasq
  services.dnsmasq = {
    enable = true;
    extraConfig = ''
      dhcp-range=192.168.1.100,192.168.1.200,24h
      enable-tftp
      tftp-root=/var/lib/tftpboot
    '';
  };

  # Enable MariaDB
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  # Enable JupyterLab
  services.jupyter = {
    enable = true;
    password = "your_password_hash";
  };

  # Window Managers
  services.xserver = {
    enable = true;
    displayManager.defaultSession = "xfce";
    windowManager = {
      qtile.enable = true;
      dwm.enable = true;
      i3.enable = true;
    };
    desktopManager.xfce.enable = true;
  };

  # System-wide packages
  environment.systemPackages = with pkgs; [
    htop tmux screen nload git tree firefox chromium
    gnumeric wget curl neovim emacs nb
    (python3.withPackages(ps: with ps; [
      dash matplotlib plotly pyvisa pyvisa-py pyusb zeroconf psutil
    ]))
  ];

  # User configuration
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "dialout" ];
    initialPassword = "hai";
  };

  # USB device access
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", MODE="0666"
  '';

  # WebSocket server
  services.websockify = {
    enable = true;
    cert = "/path/to/cert.pem";
    key = "/path/to/key.pem";
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

EOF

# Install NixOS
print_message "Installing NixOS"
nixos-install --no-root-passwd

print_message "NixOS installation complete. You can now reboot into your new system."
