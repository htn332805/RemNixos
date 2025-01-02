{ config, pkgs, ... }:

{
  home.username = "nixos";
  home.homeDirectory = "/home/nixos";
  home.stateVersion = "24.05";  # Adjust this to match your NixOS version

  programs.home-manager.enable = true;

  # Add your user-specific configurations here
  home.packages = [ pkgs.qtile ];
  xsession = {
      windowManager = {
        i3 = {
          enable = true;
          config = {
            modifier = "Mod1";
            terminal = "${pkgs.st}/bin/st";
          }; #end of config
        }; #end of i3
        qtile = {
          enable = true;
          extraConfig = ''
            from libqtile.config import Key
            from libqtile.lazy import lazy
            
            mod = "mod1"
            terminal = "${pkgs.st}/bin/st"
            
            keys = [
                Key([mod], "Return", lazy.spawn(terminal)),
            ]
          '';
        };#end of qtile
      };#end of window manger
    };#end of xsession

    home.file.".xinitrc".text = ''
      export TERMINAL=${pkgs.st}/bin/st
    '';

    home.file.".dwm/config.h".text = ''
      static const char *termcmd[]  = { "${pkgs.st}/bin/st", NULL };
      #define MODKEY Mod1Mask
    '';
}


