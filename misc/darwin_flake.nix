{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs }:
  let
    configuration = { pkgs, ... }: {
      #allowUnfree = true;
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = with pkgs;
        [ vim htop nload screen tmux tree nb neovim iterm2 neofetch wget curl obsidian cargo
          lazygit
        ];

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";
      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;
      #Unlocking sudo via fingerprint
      security.pam.enableSudoTouchIdAuth = true;
      system.defaults = {
  	dock.autohide = true;
  	dock.mru-spaces = false;
  	finder.AppleShowAllExtensions = true;
  	finder.FXPreferredViewStyle = "clmv";
  	loginwindow.LoginwindowText = "nixcademy.com";
  	screencapture.location = "~/Pictures/screenshots";
  	screensaver.askForPasswordDelay = 10;
      };#end of system.defaults
      nix.extraOptions = ''
  	extra-platforms = x86_64-darwin aarch64-darwin
	'';
      #Building Linux binaries
      nix.linux-builder.enable = true;
      nixpkgs.config.allowUnfree = true;

      # Enable alternative shell support in nix-darwin.
      programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations."Hais-MacBook-Air" = nix-darwin.lib.darwinSystem {
      modules = [ configuration ];
    };
    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Hais-MacBook-Air".pkgs;
    #Unlocking sudo via fingerprint
    security.pam.enableSudoTouchIdAuth = true;
  };
}
