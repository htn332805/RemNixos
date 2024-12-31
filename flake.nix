{
  description = "NixOS configuration with Disko and Impermanence";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
  };

  outputs = { self, nixpkgs, disko, impermanence, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      nixosConfigurations.remNixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          ./configuration.nix
          ({ config, ... }: {
            disko.devices = import ./disk-config.nix {
              inherit (config.nixpkgs) lib;
              disks = [ "/dev/sda" ]; # Adjust this to your disk
            };

            fileSystems."/persist".neededForBoot = true;
            environment.persistence."/persist" = {
              directories = [
                "/etc/nixos"
                "/var/log"
                "/var/lib/bluetooth"
                "/var/lib/nixos"
                "/var/lib/systemd/coredump"
                { directory = "/var/lib/colord"; user = "colord"; group = "colord"; mode = "u=rwx,g=rx,o="; }
              ];
              files = [
                "/etc/machine-id"
                { file = "/etc/nix/id_rsa"; parentDirectory = { mode = "u=rwx,g=,o="; }; }
              ];
            };

            boot.initrd.postDeviceCommands = pkgs.lib.mkBefore ''
              mkdir -p /mnt

              # Mount the root partition
              mount -o subvol=root /dev/disk/by-label/nixos /mnt

              # Remove all contents of the root subvolume
              btrfs subvolume list -o /mnt/root | cut -f9 -d ' ' |
              while read subvolume; do
                btrfs subvolume delete "/mnt/$subvolume"
              done
              rm -rf /mnt/root/*

              # Create a blank root subvolume
              btrfs subvolume delete /mnt/root
              btrfs subvolume create /mnt/root

              # Unmount everything
              umount /mnt
            '';
          })
        ];
      };

      packages.${system}.default = self.nixosConfigurations.remNixos.config.system.build.toplevel;

      apps.${system}.default = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "apply-system" ''
          set -e
          echo "Formatting and mounting disks..."
          ${disko.packages.${system}.default}/bin/disko --mode destroy,format,mount ${./disk-config.nix}
          echo "Installing NixOS..."
          nixos-install --flake .#remNixos
          echo "Done! You can now reboot into your new system."
        ''}/bin/apply-system";
      };
    };
}
