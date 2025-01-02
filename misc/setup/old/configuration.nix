
{ config, pkgs, lib,  ... }:
let
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in

{
  imports = [ "${impermanence}/nixos.nix" ./hardware-configuration.nix 
	#"${builtins.fetchGit { url = "https://github.com/NixOS/nixos-hardware.git"; }}"/raspberry-pi/4"
  ];

  # Boot loader
  boot.loader.grub = {
    enable = true;
    #device = "nodev";
    device = "/dev/sdc;
    efiSupport = true;
    useOSProber = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.extraEntries = ''
    menuentry "rEFInd" {
      insmod part_gpt
      insmod fat
      insmod search_fs_uuid
      insmod chain
      search --fs-uuid --set=root  FF4A-571B
      chainloader /EFI/refind/refind_x64.efi
    }
  '';

  # ZFS support
  boot.supportedFilesystems = [ "zfs" "btrfs" "ntfs" "squashfs" "exfat" "ext2" "ext3" "ext4" "xfs"];
  boot.zfs.requestEncryptionCredentials = true;

  # Networking
  networking.hostName = "hainixos";
  networking.hostId = "12345678";
  networking.networkmanager.enable = true;

  # Time zone
  time.timeZone = "UTC";

  # Impermanence
  environment.persistence."/persist" = {
    directories = [
      "/etc/nixos"
      "/var/log"
      "/var/lib"
    ];
    files = [
      "/etc/machine-id"
    ];
  };

  # XRDP
  services.xrdp = {
    enable = true;
    defaultWindowManager = "x11vnc";
  };

  # Nginx
  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      root = "/var/www/localhost";
      locations."/" = {
        index = "index.html";
      };
    };
  };

  # NFS Server
  services.nfs.server = {
    enable = true;
    exports = ''
      /exports 192.168.1.0/24(rw,sync,no_subtree_check)
    '';
  };

  # ATFTP
  services.atftpd = {
    enable = true;
    root = "/srv/tftp";
  };

  # DNSMasq
  services.dnsmasq = {
    enable = true;
    extraConfig = ''
      dhcp-range=192.168.1.50,192.168.1.150,12h
      enable-tftp
      tftp-root=/srv/tftp
      dhcp-boot=pxelinux.0
    '';
  };

  # MariaDB
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  # JupyterLab
  services.jupyterhub = {
    enable = true;
    # Use JupyterLab as the default interface
    extraConfig = ''
      c.Spawner.default_url = '/lab'
      c.Spawner.cmd = ['jupyterhub-singleuser', '--SingleUserNotebookApp.default_url=/lab']
      c.DummyAuthenticator.password = "hai"
    '';
    # Set up authentication (you may want to use a more secure method in production)
    # Set the authentication type to "dummy" if you want to use dummy authentication
    authentication = "dummy";
  };
  # Window Managers
  services.xserver = {
    layout = lib.mkDefault "us";
    xkbOptions = "altwin:swap_alt_win";
    enable = true;
    displayManager.defaultSession = "none+qtile";
    windowManager = {
      qtile.enable = true;
      dwm.enable = true;
      i3.enable = true;
    };
    desktopManager.xfce.enable = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    htop tmux screen nload git tree firefox chromium xrdp x11vnc git alejandra comma deadnix devenv mandix nh nixfmt nixpkgs-fmt nix-alien nix-diff nix-du nix-index nix-init nix-melt nix-output-monitor nix-prefetch nix-tree nurl nvd statix attic arion
    gnumeric wget curl neovim emacs nb cached-nix-shell devshell flake.parts flakes-utils flake-utils-plus flakelight lorri nil neofetch nnn zip xz unzip p7zip ripgrep q yq-go eza fzf mtr iperf3 dnsutils ldns aria2 socat nmap ipcalc cowsay file which
    tree gnused gnutar gawk zstd gnupg hugo glow btop iotop iftop strace ltrace lsof sysstat lm_sensors ethtool pciutils usbutils
    (python3.withPackages (ps: with ps; [
      jupyterlab pyvisa pyvisa-py matplotlib plotly pyusb zeroconf psutil dash websockify
      ipykernel
      # Add other Python packages you need
    ]))
  ];

  # User configuration
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "dialout" ];
    initialPassword = "hai";
  };
  
  services.x11vnc = {
	enable = true;
   	auth = "/home/nixos/.Xauthority";
	passwd ="hai"
	autoStart = true;
  };

  # USB access
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", MODE="0666"
  '';

  # WebSocket server
  systemd.services.websockify = {
    description = "Websockify Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      ExecStart = "${pkgs.python3Packages.websockify}/bin/websockify 0.0.0.0:6080 --ssl-only --cert=/path/to/your/cert.pem --key=/path/to/your/key.pem";
      Restart = "always";
      RestartSec = "10";
      User = "nobody";
      Group = "nobody";
    };
  };

  # Set proper permissions for SSL files
  systemd.services.websockify.serviceConfig = {
    ReadOnlyPaths = [ "/path/to/your/cert.pem" "/path/to/your/key.pem" ];
  };

  # Vim and Neovim configuration
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    configure = {
      customRC = ''
        " Your custom Vim/Neovim configuration here
      '';
      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [ vim-airline vim-airline-themes vim-nix ];
      };
    };
  };

  programs.st ={
	enable = true;
	# optional:
  };

  environment.variables = {

	TERMINAL = "st";
  ];

  networking.firewall.allowedTCPPorts = [22 80 3389 5900 8080];  

  # System-wide configuration
  system.stateVersion = "24.05";
}
