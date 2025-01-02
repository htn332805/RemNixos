{ config, pkgs, ... }:

{
  # Define a user account
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "hai";
  };
}
