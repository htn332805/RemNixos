cd /mnt/boot
echo "unzip pi bootloader"
#unzip /root/t/config_files/RPi4_UEFI_Firmware_v1.33.zip
mkdir -p /mnt/persist/etc/ssh
sleep 5
mkdir -p /mnt/persist/etc/NetworkManager/system-connections
sleep 5
mkdir -p /mnt/persist/var/lib/bluetooth
mkdir -p /mnt/persist/var/lib/tftpboot
mkdir -p /mnt/persist/var/log
mkdir -p /mnt/persist/var/nfs
sleep 5
mkdir -p /persist/etc/ssh
sleep 5
mkdir -p /mnt/persist/etc
sleep 5
mkdir -p /mnt/persist/var/www
sleep 5
mkdir -p /mnt/persist/var/atftp
sleep 15
echo "Permit ZFS auto-snapshots on datasets ..."
zfs set com.sun:auto-snapshot=true rpool/safe/home
sleep 5
zfs set com.sun:auto-snapshot=true rpool/safe/persist
echo "Generating NixOS configuration (/mnt/etc/nixos/*.nix) ..."
sleep 5
rm -rvf /mnt/etc/nixos/*
nixos-generate-config --root /mnt
sleep 5
echo "Moving generated hardware-configuration.nix to /persist/etc/nixos/ ..."
mkdir -p /mnt/persist/etc/nixos
sleep 5
mv /mnt/etc/nixos/* /mnt/persist/etc/nixos
cp -rvf /root/t/config_files/* /mnt/persist/etc/nixos
ln -s /mnt/persist/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix
ln -s /mnt/persist/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix
ln -s /mnt/persist/etc/nixos/flake.nix /mnt/etc/nixos/flake.nix
ln -s /mnt/persist/etc/nixos/home.nix /mnt/etc/nixos/home.nix
ln -s /mnt/persist/etc/nixos/modules /mnt/etc/nixos/modules
ln -s /mnt/persist/etc/nixos/shadow /mnt/etc/shadow
ln -s /mnt/persist/var /mnt/var
