{ config, pkgs, ... }:

{
  home.username = "nixos";
  home.homeDirectory = "/home/nixos";
  home.stateVersion = "24.05";  # Adjust this to match your NixOS version

  programs.home-manager.enable = true;

}


