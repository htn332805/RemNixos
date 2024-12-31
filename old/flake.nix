{
  description = "NixOS configuration with Disko and Impermanence";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
  };

  outputs = { self, nixpkgs, disko, impermanence, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          ./configuration.nix
          {
            disko.devices = import ./disk-config.nix {
              inherit (pkgs) lib;
            };
            
            fileSystems."/" = {
              device = "rpool/local/root";
              fsType = "zfs";
            };

            fileSystems."/nix" = {
              device = "rpool/local/nix";
              fsType = "zfs";
            };

            fileSystems."/home" = {
              device = "rpool/safe/home";
              fsType = "zfs";
            };

            fileSystems."/persist" = {
              device = "rpool/safe/persist";
              fsType = "zfs";
              neededForBoot = true;
            };

            boot.initrd.postDeviceCommands = pkgs.lib.mkAfter ''
              zfs rollback -r rpool/local/root@blank
            '';

            environment.persistence."/persist" = {
              directories = [
                "/etc/nixos"
                "/var/log"
                "/var/lib/bluetooth"
                "/var/lib/nixos"
                "/var/lib/systemd/coredump"
              ];
              files = [
                "/etc/machine-id"
                "/etc/ssh/ssh_host_ed25519_key"
                "/etc/ssh/ssh_host_ed25519_key.pub"
                "/etc/ssh/ssh_host_rsa_key"
                "/etc/ssh/ssh_host_rsa_key.pub"
              ];
            };
          }
        ];
      };

      packages.${system}.default = self.nixosConfigurations.default.config.system.build.diskoScript;
    };
}
