{ config, lib, pkgs, ... }:

{
  services.xserver = {
    enable = true;
    layout = "us";
    
    desktopManager = {
      xfce.enable = true;
    };
    
    windowManager = {
      qtile.enable = true;
      i3 = {
        enable = true;
        extraPackages = with pkgs; [
          dmenu
          i3status
          i3lock
        ];
      };
      dwm.enable = true;
    };
    
    displayManager = {
      defaultSession = "none+i3";
      lightdm.enable = true;
    };
  };

  # Set st as the default terminal
  environment.systemPackages = with pkgs; [
    st
  ];

}
