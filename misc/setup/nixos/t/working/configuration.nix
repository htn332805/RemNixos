{ config, pkgs, lib, ... }:
{
  imports =
    [ 
      ./hardware-configuration.nix
      ./users.nix
      ./networking.nix
      ./packages.nix
      ./bootloader.nix
    ];

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
  services.openssh.enable = true;
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "24.05";
}
