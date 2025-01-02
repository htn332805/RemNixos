{
  description = "Hai Nixos config";
  inputs = {
	nixpkgs.url = "nixpkgs/nixos-24.05";
	home-manager.url = "github:nix-community/home-manager/release-24.05";
	home-manager.inputs.nixpkgs.follows = "nixpkgs";
  }; #END OF INPUTS
  outputs = { nixpkgs, home-manager, ...  }: 
     let
	system = "armv7l";
	#system = "aarch64";
	#system = "x86_64-linux";
	pkgs = import nixpkgs {
		inherit system;
		config = { allowUnfree = true; };
	}; #end of pkgs
  	lib = nixpkgs.lib;
     in {
	homeManagerConfigurations = {
		nixos = home-manager.lib.homeManagerConfiguration {
			inherit system pkgs;
			username = "nixos";
			homeDirectory = "/home/nixos";
			configuration = {
				imports = [
					./users/nixos/home.nix
				]; #end of import
			}; #end of home configuraton
		};
	}; #end of home manager config
	nixosConfigurations = {
		hainixos = lib.nixosSystem {
			inherit system;
			modules = [
				#(_: { nixpkgs.overlays = [ qtile-flake.overlays.default ]; })
				./configuration.nix	
				home-manager.nixosModules.home-manager
        			{
          				home-manager.useGlobalPkgs = true;
          				home-manager.useUserPackages = true;
          				home-manager.users.nixos = import ./home.nix;
        			}#end of home-manger bracket	
				#./modules/xrdp.nix	
				./modules/desktop.nix	
				./modules/xrdp.nix
				./modules/nginx.nix
                                ({ config, ... }: {
					services.atftpd = {
              					enable = true;
				                root = "/persist/var/lib/tftpboot";
				                extraOptions = [
					                "--port 69"
					                "--daemon"
					                "--user nobody"
					                "--group nogroup"
					                "--logfile /persist/var/log/atftpd.log"
					                "--verbose=7"
				              ];#end of extraoptions
			               };#end of services
				       networking.firewall.allowedUDPPorts = [ 69 ];
            			       # Ensure the TFTP root directory exists
                                       system.activationScripts.tftpboot = ''
                                       mkdir -p /persist/var/lib/tftpboot
                                       chmod 755 /persist/var/lib/tftpboot
                                       chown nobody:nogroup /persist/var/lib/tftpboot
                                       '';
                                       # Set up log rotation for atftpd log
				       services.logrotate = {
              					enable = true;
              					settings = {
                					"/persist/var/log/atftpd.log" = {
                  						rotate = 7;
                  						weekly = true;
                  						missingok = true;
                  						notifempty = true;
                  						compress = true;
                  						postrotate = "systemctl kill -s HUP atftpd.service";
                					};# end of atftp.log
              					};#end of settings
            				};#end of logrotate
				})#end of atftp config
				./modules/nfs.nix
				./modules/dnsmasq.nix
				({ config, ... }: {
				          services.customDnsmasq = {
            				  enable = true;
            				  interface = "enabcm6e4ei0";
			                  dhcpRange = "192.168.1.50,192.168.1.150,12h";
                                          pxeBootFile = "pxelinux.0";
                                          tftpRoot = "/persist/var/lib/tftpboot";
          				};#end of dnsmasq services
        			})#end of customednsmasq
			 ]; #end of modules
		}; #end of hai_nixos
	}; #end of nixosConfig
     }; #end of in	
} # end of top bracket


