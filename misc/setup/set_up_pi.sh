drive=$1
wipefs -a /dev/$drive
sleep 5
parted -a optimal /dev/$drive -- mklabel gpt
sleep 5
parted -a optimal /dev/$drive -- mkpart ESP fat32 1MiB 513MiB
sleep 5
parted -a optimal /dev/$drive -- set 1 esp on
sleep 5
parted -a optimal /dev/$drive -- mkpart primary 513MiB 521MiB
sleep 5
parted -a optimal /dev/$drive -- set 2 bios_grub on
sleep 5
parted -a optimal /dev/$drive -- mkpart primary linux-swap 521MiB 8705MiB
sleep 5
parted -a optimal /dev/$drive -- mkpart primary 8705MiB 100%
sleep 5

mkfs.fat -F 32 -n EFI /dev/"$drive"1
sleep 5
mkswap -L swap /dev/"$drive"3
sleep 5
swapon /dev/"$drive"3
sleep 5

zpool create -f -o autoexpand=on -O mountpoint=none -O atime=off -o ashift=12 -O acltype=posixacl -O xattr=sa -O compression=zstd -O dnodesize=auto -O normalization=formD rpool /dev/"$drive"4
sleep 5
zfs create -o refreservation=1G -o mountpoint=none rpool/reserved
sleep 5
zfs create -p -o mountpoint=legacy rpool/local/root
sleep 5
zfs snapshot rpool/local/root@blank
sleep 5
mount -t zfs rpool/local/root /mnt
sleep 5

mkdir /mnt/boot
sleep 5
mount /dev/"$drive"1 /mnt/boot
sleep 5
zfs create -p -o mountpoint=legacy rpool/local/nix
sleep 5
mkdir /mnt/nix
sleep 5
mount -t zfs rpool/local/nix /mnt/nix
sleep 5
zfs create -p -o mountpoint=legacy rpool/safe/home
sleep 5
mkdir /mnt/home
sleep 5
mount -t zfs rpool/safe/home /mnt/home
sleep 5
zfs create -p -o mountpoint=legacy rpool/safe/persist
sleep 5
mkdir /mnt/persist
sleep 5
mount -t zfs rpool/safe/persist /mnt/persist
sleep 5
nix-shell -p wget unzip
sleep 15
cd /mnt/boot && wget https://github.com/pftf/RPi4/releases/download/v1.33/RPi4_UEFI_Firmware_v1.33.zip && unzip RPi4_UEFI_Firmware_v1.33.zip
echo "Creating persistent directories ..."
mkdir -p /mnt/persist/etc/ssh
sleep 5
mkdir -p /persist/etc/NetworkManager/system-connections
sleep 5
mkdir -p /persist/var/lib/bluetooth
sleep 5
mkdir -p /persist/etc/ssh
sleep 5
mkdir -p /mnt/persist/etc
sleep 5
mkdir -p /mnt/persist/var/www
sleep 5
mkdir -p /mnt/persist/var/atftp
sleep 15
echo "Permit ZFS auto-snapshots on rpool/safe datasets ..."
zfs set com.sun:auto-snapshot=true rpool/safe/home
sleep 5
zfs set com.sun:auto-snapshot=true rpool/safe/persist
echo "Generating NixOS configuration (/mnt/etc/nixos/*.nix) ..."
sleep 5
nixos-generate-config --root /mnt
sleep 5
echo "Moving generated hardware-configuration.nix to /persist/etc/nixos/ ..."
mkdir -p /mnt/persist/etc/nixos
sleep 5
mv /mnt/etc/nixos/hardware-configuration.nix /mnt/persist/etc/nixos/
sleep 5
echo "Backing up the originally generated configuration.nix to /persist/etc/nixos/configuration.nix.original ..."
mv /mnt/etc/nixos/configuration.nix /mnt/persist/etc/nixos/configuration.nix.original
sleep 5
NIXEL="$(dirname "$(readlink -fm "$0")")"
sleep 5
cp -r $NIXEL /mnt/persist/etc/
cp -rvf /root/t/config_files/* /mnt/persist/etc/nixos
nix-shell -p git tmux htop screen git nload
