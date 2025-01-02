{ config, lib, pkgs, ... }:

{
  services.xserver = {
    enable = true;
    layout = "us";
    
    desktopManager = {
      xfce.enable = true;
    }; #end of desktopmanager
    
    windowManager = {
      qtile.enable = true;
      i3 = {
        enable = true;
        extraPackages = with pkgs; [
          dmenu
          i3status
          i3lock
        ]; #end of extrapackages
      };
      dwm.enable = true;
    }; #end of windows manager
    
    displayManager = {
      defaultSession = "none+qtile";
      lightdm.enable = true;
    }; #end of display maanger
  }; #end of xserver

  # Set st as the default terminal
  environment.systemPackages = with pkgs; [
    st htop screen tmux nload git vim neovim nb gnumeric
  ]; #end of environment packages

}#end of the very top braket
