{ config, pkgs, ... }:

{
  networking = {
    hostName = "nixos";
    hostId = "1f4805e1";
    networkmanager.enable = true;
  };
}
