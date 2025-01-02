{ config, pkgs, ... }: {

  services.xrdp = {
  	enable = true;
        defaultWindowManager = "xfce4-session";
        openFirewall = true;
        }; #end of xrdp config
  networking.firewall.allowedTCPPorts = [ 3389 22 5900];
  # Enable and configure x11vnc
  systemd.services.x11vnc = {
  	description = "x11vnc server";
        after = [ "display-manager.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
        ExecStart = "${pkgs.x11vnc}/bin/x11vnc -display :0 -auth guess -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.pass -rfbport 5900 -shared";
              Restart = "on-failure";
            }; #end of service config
          }; #end of x11vnc config
# Custom XRDP configuration
environment.etc."xrdp/xrdp.ini".text = ''
            [Xvnc]
            name=Xvnc
            lib=libvnc.so
            ip=127.0.0.1
            port=5900
            username=ask
            password=ask
          '';

}


