{
  description = "Hai Nixos config";
  inputs = {
	nixpkgs.url = "nixpkgs/nixos-24.05";
	home-manager.url = "github:nix-community/home-manager/release-24.05";
	home-manager.inputs.nixpkgs.follows = "nixpkgs";
  }; #END OF INPUTS
  outputs = { nixpkgs, home-manager, ...  }: 
     let
	#system = "armv7l";
	#system = "aarch64";
	system = "x86_64-linux";
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
			 ]; #end of modules
		}; #end of hai_nixos
	}; #end of nixosConfig
     }; #end of in	
} # end of top bracket


