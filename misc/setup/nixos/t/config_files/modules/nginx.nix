{ config, lib, pkgs, ... }:
{
  # Enable Nginx web server
  services.nginx = {
  	enable = true;
        virtualHosts."localhost" = {
        locations."/var/www" = {
                root = pkgs.writeTextDir "index.html" ''
                  <!DOCTYPE html>
                  <html lang="en">
                  <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>System Monitoring</title>
                    <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.0.1/socket.io.js"></script>
                    <script>
                      const socket = io();
                      socket.on('update', (data) => {
                        document.getElementById('htop').innerText = data.htop;
                        document.getElementById('nload').innerText = data.nload;
                      });
                    </script>
                  </head>
                  <body>
                    <h1>System Monitoring</h1>
                    <h2>htop output:</h2>
                    <pre id="htop"></pre>
                    <h2>nload output:</h2>
                    <pre id="nload"></pre>
                  </body>
                  </html>
                ''; #end of writetextdir
              }; #end of locations
            }; #end of virtualhosts
          }; #end of services

  # Enable and configure the monitoring service
  systemd.services.system-monitor = {
  	description = "System Monitoring Service";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
        ExecStart = "${pkgs.writeShellScript "monitor.sh" ''
                ${pkgs.nodejs}/bin/node ${pkgs.writeText "server.js" ''
                  const http = require('http');
                  const { Server } = require('socket.io');
                  const { exec } = require('child_process');

                  const server = http.createServer();
                  const io = new Server(server);

                  io.on('connection', (socket) => {
                    console.log('Client connected');

                    const updateInterval = setInterval(() => {
                      exec('htop -C -t -d 10 | head -n 10', (error, htopOutput) => {
                        exec('nload -t 1000 -i 102400 -o 102400 | head -n 10', (error, nloadOutput) => {
                          socket.emit('update', { htop: htopOutput, nload: nloadOutput });
                        });
                      });
                    }, 1000);

                    socket.on('disconnect', () => {
                      clearInterval(updateInterval);
                      console.log('Client disconnected');
                    });
                  });

                  server.listen(3000, () => {
                    console.log('Monitoring server running on port 3000');
                  });
                ''}
              ''}";
              Restart = "always";
              RestartSec = "10";
            };#end of service config
          };#end of systemd

  # Install required packages
  environment.systemPackages = with pkgs; [
            htop
            nload
            nodejs
          ];

  # Open firewall ports
  networking.firewall.allowedTCPPorts = [ 80 3000 ];
}
