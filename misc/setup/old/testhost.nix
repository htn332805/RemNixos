{ config, pkgs, lib, inputs, ... }:

let
  arcMaxMiB = 512;

  rootDiffScript = pkgs.writeShellScriptBin "my-root-diff" ''
    ${pkgs.zfs}/bin/zfs diff rpool/local/root@blank
  '';

  filterExistingGroups = groups:
    builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  imports = [
    inputs.nixpkgs.nixosModules.notDetected
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    # ./qemu-guest.nix"
    ./vbox-guest.nix
  ];

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    gc = {
      automatic = true;
      dates = "weekly";
    };
    package = pkgs.nixVersions.nix_2_16;
    settings = {
      warn-dirty = false;
      trusted-users = [ "root" "@wheel" ];
      auto-optimise-store = true;
    };

    # Credits: Misterio77
    # https://raw.githubusercontent.com/Misterio77/nix-config/e227d8ac2234792138753a0153f3e00aec154c39/hosts/common/global/nix.nix

    # Add each flake input as a registry
    registry = lib.mapAttrs (_: v: { flake = v; }) inputs;

    # Map registries to channels (useful when using legacy commands)
    nixPath = lib.mapAttrsToList
      (n: v: "${n}=${v.to.path}")
      config.nix.registry;
  };

  nixpkgs.config.allowUnfree = true;

  # Create TFTP root directory
  #system.activationScripts = {
  #  tftpboot = {
  #    text = ''
  #      mkdir -p /var/lib/tftpboot
  #      chmod 755 /var/lib/tftpboot
  #    '';
  #    deps = [];
  #  };
  #};


  # Ensure dnsmasq can write to syslog
  #security.wrappers.dnsmasq = {
  #  source = "${pkgs.dnsmasq}/bin/dnsmasq";
  #  capabilities = "cap_net_bind_service,cap_net_admin+ep";
  #};

  boot = {
    # Activate opt-in impermanence
    initrd.postDeviceCommands = lib.mkAfter ''
      zfs rollback -r rpool/local/root@blank
    '';

    kernelParams = [
      "nohibernate"
      "elevator=none" "net.ifnames=0" 
      "audit=0" "copytoram" "ipv6.disable=1" 
      "console=ttyS0,115200" "console=tty0"
      # WORKAROUND: get rid of error
      # https://github.com/NixOS/nixpkgs/issues/35681
      "systemd.gpt_auto=0"
      "zfs.zfs_arc_max=${toString (arcMaxMiB * 1048576)}"
    ];
    kernelModules = [ "kvm-intel" "pktgen" "nfs" ];
    zfs.forceImportRoot = true;
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages; 
    supportedFilesystems = [ "zfs" "exfat" "ntfs" "ext2" "ext3" "ext4" "btrfs" "xfs" "squashfs" "fat16" "fat32" "hfs" "f2fs" "hfs+" "jfs" "linux-swap" "lvm" "lvm2" "lvm2 pv" "minix" "milfs2" "reiser4" "reiserfs" "udf" ]; 
    loader.efi.efiSysMountPoint = "/boot";
    loader.generationsDir.copyKernels = true;
    #loader.refind = {
    #	enable = true;
    #	extraConfig = ''
    #		console=tty0 console=ttyS0,115200 copytoram audit=0 ipv6.disable=1
    #	'';
    #	}; #end of refind
    loader.grub = {
      enable = true;
      efiSupport = true;
      useOSProber = true;
      copyKernels = true;
      efiInstallAsRemovable = true;
      device = "/dev/sda";
      zfsSupport = true;
      #device = "nodev";
      #mirroredBoots = [
      #  { devices = [ "nodev" ]; path = "/boot1"; efiSysMountPoint = "/boot1"; }
      #  { devices = [ "nodev" ]; path = "/boot2"; efiSysMountPoint = "/boot2"; }
      #];
      extraEntries = ''
	menuentry "rEFInd" {
		insmod part_gpt
		insmod fat
		insmod chain
		search --no-floppy --fs-uuid --set=root /dev/sda
		chainloader /EFI/refind/refind_x64.efi
	}
	'';
	}; #end of grub
  }; #end of boot

  time.timeZone = "America/Los_Angeles";

  console = {
    font = "ter-v22n";
    keyMap = lib.mkDefault  "us";
    packages = [ pkgs.terminus_font ];
    earlySetup = true;
    #useXkbConfig = true; # use xkb.options in tty.
  };

  i18n.defaultLocale = "en_US.UTF-8";

  # neededForBoot flag is not settable from disko
  fileSystems = {
    "/var/log".neededForBoot = true;
    "/persistent".neededForBoot = true;
  };

  networking = {
    hostName = "testhost";
    hostId = "12345678";
    # Generate host ID from hostname
    #hostId = builtins.substring 0 8 (
     # builtins.hashString "sha256" config.networking.hostName
    #);
    # useDHCP = false;
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 22 53 69 80 111 514 2049 3000 3389 5900 8000 8888 20048];
    firewall.allowedUDPPorts = [ 22 53 67 68 69 80 111 514 2049 3000 3389 5900 20048 ];
  };

  environment = {
    variables = {
   	EDITOR = "vim";
	TERMINAL = "st";
  	}; #end of variables
    etc."xrdp/xrdp.ini".text = ''
	[Xvnc]
	name=Xvnc
	lib=libvnc.so
	ip=127.0.0.1
	port=5900
	username=ask
	password=ask
	'';
    persistence."/persistent" = {
      hideMounts = true;
      directories = [
        # {
        #   directory = "/etc/NetworkManager/system-connections";
        #   mode = "u=rwx,g=,o=";
        # }
        "/etc/ssh/authorized_keys.d"
        "/var/lib/upower"
      ];
      files = [
        "/etc/adjtime"
        "/etc/machine-id"
        "/etc/zfs/zpool.cache"
      ];
    };

    systemPackages = [ rootDiffScript  
    ] ++ (with pkgs; [
	st xrdp x11vnc git vim wget curl firefox chromium neovim screen htop tmux emacs nb lynx links2 elinks mc gdu ripgrep fd fzf gcc gnumake cmake python3 nodejs nix-index nix-prefetch-git neofetch nixpkgs-fmt zsh nmap iperf3 fio sysstat ranger ncdu tree jq yq pandoc docker podman direnv starship oh-my-fish python3Packages.pip python3Packages.virtualenv libffi openssl minicom nix-diff nix-du nix-init nix-melt nix-output-monitor nix-tree nix-update poetry alacritty gptfdisk gparted parted gnumeric dwm xorg.xinit xorg.xorgserver xterm xfce.thunar xfce.xfce4-whiskermenu-plugin xlsx2csv sc-im grub2 refind coreutils nnn zip xz unzip p7zip mtr dnsutils ldns aria2 socat nmap ipcalc cowsay file which tree gnused gnutar gawk zstd gnupg hugo glow btop iftop nload iotop strace ltrace lsof lm_sensors ethtool pciutils usbutils lnav nfs-utils
	(python3.withPackages (ps: with ps; [ jupyterlab ipykernel jupyterlab-widgets ipywidgets dash matplotlib plotly pandas numpy pyvisa pyvisa-py pyusb zeroconf psutil ])) 
	]);#end of systempackages
  };

  programs = {
    git.enable = true;
    tmux.enable = true;
    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
    };
  };

  services = {
    openssh = {
      enable = true;
      hostKeys = [
        {
          bits = 4096;
          path = "/persistent/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
        }
        {
          path = "/persistent/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };# end of openssh

    zfs = {
      trim.enable = true;
      autoScrub = {
        enable = true;
        pools = [ "rpool" ];
      }; #end of auto scrub
      autoSnapshot = {
	enable = true;
      };#end snapshot
    };#end of zfs

   atftpd = {
	enable = true;
	root = "/home/nixos"; #set teh tftp root directory
	extraOptions = [
		"--verbose=7" #enable verbose logging
		"--logfile /var/log/atftpd.log" #set log file path
	];#end of extra options
   }; #end of atftpd

  # Enable NFS server
  nfs.server = {
    enable = true;
    exports = ''
      /home/nixos 192.168.1.0/24(rw,sync,no_subtree_check)  #share directory
    '';
   extraNfsdConfig = ''
	udp=n
    	vers3=n
    	vers4=y
    	vers4.0=n
    	vers4.1=y
    	vers4.2=y 
	'';   
  };#end of nfs setting

  # Enable required services
  rpcbind.enable = true;

  dnsmasq = {
    enable = true;
    settings = {
      # DHCP server configuration
      dhcp-range = "192.168.1.115,192.168.1.150,48h";
      dhcp-option = [
        "3,192.168.1.1"  # Set default gateway
        "6,192.168.1.1"  # Set DNS server
      ];
      
      # PXE server configuration
      enable-tftp = true;
      tftp-root = "/var/lib/tftpboot";
      dhcp-boot = "pxelinux.0";
      
      # Logging configuration
      log-dhcp = true;
      log-queries = true;
      
      # Interface to listen on (adjust as needed)
      interface = "enp0s3";
      
      # Other useful settings
      domain-needed = true;
      bogus-priv = true;
      expand-hosts = true;
      domain = "local";
    };#end of setting
  };#end of dnsmasq

  # Enable MariaDB
  mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings = {
      mysqld = {
        bind-address = "127.0.0.1";  # Adjust if needed
        max_connections = 900;  # Adjust based on your needs
      };#end of mysqld
    };#end of mysql setting
  };#end of mysql

  # Create a database and user for JupyterHub (adjust as needed)
  mysql.initialDatabases = [
    { name = "jupyterhub"; }
  ];
  mysql.ensureUsers = [
    {
      name = "jupyterhub";
      ensurePermissions = {
        "jupyterhub.*" = "ALL PRIVILEGES";
      };
    }
  ];



  logrotate = {
	enable = true;
	settings = {
		atftpd = {
			files = "/var/log/atftpd.log";
			frequency = "daily";
			rotate = 7;
			compress = true;
			delaycompress = true;
			missingok = true;
			notifempty = true;
		}; #end of logrotate
		"/var/log/dnsmasq.log" = {
        		rotate = 7;
        		weekly = true;
        		compress = true;
        		delaycompress = true;
        		missingok = true;
        		notifempty = true;
      		};#end of dnsmasq
		"/var/log/nfs.log" = {
        		rotate = 7;
        		weekly = true;
        		compress = true;
        		delaycompress = true;
        		missingok = true;
        		notifempty = true;
      		};#end of nfs log
		"/var/log/mysql/mysql.log" = {
        		rotate = 7;
        		daily = true;
        		missingok = true;
        		create = "640 mysql adm";
        		postrotate = "/usr/bin/mysqladmin flush-logs";
      		};#end of mysql log
	}; #end of settings
  };#end of logrotate

   rsyslogd = {
	enable = true;
	defaultConfig = ''
		#Log atftpd message
		if $programname ==  "atftpd" then /var/log/atftpd.log
		& stop
		# Log dnsmasq messages to a separate file
      		:programname, isequal, "dnsmasq" /var/log/dnsmasq.log
      		& stop
		# Log NFS-related messages to a separate file
      		:programname, startswith, "nfs" /var/log/nfs.log
      		& stop
		# Global directives
      		$ModLoad imuxsock
      		$ModLoad imjournal
      		$ModLoad imudp
      		$ModLoad imtcp

      		# Set default permissions for all log files
      		$FileOwner root
      		$FileGroup adm
      		$FileCreateMode 0640
      		$DirCreateMode 0755
      		$Umask 0022

      		# Listen for UDP syslog messages on port 514
      		$UDPServerRun 514

      		# Listen for TCP syslog messages on port 514
      		$InputTCPServerRun 514

      		# Rules
      		*.* /var/log/messages
	'';
   }; #end of rsyslog

    xserver = {
	enable = true;
	layout = lib.mkDefault "us";
	xkbOptions = lib.mkDefault "altwin:swap_alt_win";
    	desktopManager = {
		xfce = {
			enable = true;
		}; #end of xfce  
	};#end of desktopmanager  
        windowManager = {
		qtile = {
			enable = true;
			configFile = pkgs.writeText "qtile-config.py" ''
			      from libqtile import layout, bar, widget, hook
			      from libqtile.config import Key, Group, Match, Screen
			      from libqtile.lazy import lazy

			      mod = "mod1"  # Use Alt as the mod key
			      terminal = "st"  # Set st as the default terminal

			      keys = [
			        # A list of available commands that can be bound to keys can be found
			        # at https://docs.qtile.org/en/latest/manual/config/lazy.html
			        Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),
			        # Add more key bindings here
			      ]

			      # Rest of your Qtile configuration goes here
			      # ...
		    '';
		}; #end of qtile
    		i3 = {
        		enable = true;
        		extraPackages = with pkgs; [
                		dmenu
                		i3status
                		i3lock
				st
        		];#edn of extra package
			configFile = pkgs.writeText "i3-config-file" ''
    				# Set mod key to Alt
    				set $mod Mod1

    				# Set st as default terminal
    				bindsym $mod+Return exec st

    				# Your other i3 configurations go here
    				# ...

    				# Example: reload the configuration file
    				bindsym $mod+Shift+c reload

    				# Example: restart i3 inplace
    				bindsym $mod+Shift+r restart

    				# Example: exit i3
    				bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Do you really want to exit i3?' -B 'Yes, exit i3' 'i3-msg exit'"
  			'';#end of config file
		}; #end of i3
    		dwm = {
			enable = true;
			#package = pkgs.dwm.overrideAttrs (oldAttrs: {
    			#	src = pkgs.fetchurl {
      			#	url = "https://dl.suckless.org/dwm/dwm-6.4.tar.gz";
      			#	sha256 = "sha256-Ideev6ny+5MUGDbCZmy4H0eExp1k5/GyNS+blwuglyk=";
    		       #		};#end of src
    			#	postPatch = oldAttrs.postPatch or "" + ''
      			#	sed -i 's/"st"/"${pkgs.st}/bin\/st"/g' config.def.h
    			#	'';
  			});#end of packages
			#config = {
			#	moddkey = "Mod1"; #use ALT as the super key
			#	terminal = "${pkgs.st}/bin/st";
			#};#end of config
		};#end of dw
	}; #end of window manager
         displayManager = {
		defaultSession = "none+dwm";
    		lightdm.enable = true;
	}; #nd of displaymanger
    };
    xrdp.enable = true;
    xrdp.defaultWindowManager = "dwm";
    xrdp.openFirewall = true;
    # Enable CUPS to print documents.
    # services.printing.enable = true;
    # Enable sound.
    pipewire = {
     enable = true;
     pulse.enable = true;
    }; #end of pipewire
    # Enable Nginx web server
    nginx = {
       enable = true;
           virtualHosts."localhost" = {
              locations."/home/nixos/" = {
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
                '';
              }; #end of location
            };#end of virtual host
          }; #end of nginx
    # Optional: Configure automatic MariaDB backups
    mysql.settings.mysqld.log-bin = "/var/lib/mysql/mysql-bin";
    mysql.settings.mysqld.binlog-expire-logs-seconds = 604800;  # 1 week
  }; #end of services
  
security.sudo.extraConfig = ''
    # Rollback results in sudo lectures after each reboot
    Defaults lecture = never
  '';

  systemd = {
    enableEmergencyMode = false;
    tmpfiles.rules = [
	"d /var/log/atftpd 0755 root root -"
	"d /home/jupyter/notebooks 0755 jupyter jupyter -"
    ]; #end of tempfiles
    # Ensure MariaDB starts before JupyterHub
    services.x11vnc = {
	description = "x11vnc server";
	after = [ "display-manager.service" ];
	wantedBy = [ "multi-user.target" ];
	serviceConfig = {
		ExecStart = " ${pkgs.x11vnc}/bin/x11vnc -display :0 -auth guess -forever -loop -noxdamages -repeat -rfbauth /etc/x11vnc.pass rfbport 5900 -shared";
		Restart = "on-failure";
	}; #end of service config
    }; #end of x1vnc services
    # Explicitly disable ZFS mount service since we rely on legacy mounts
    services.zfs-mount.enable = false;
    extraConfig = ''
      DefaultTimeoutStartSec=20s
      DefaultTimeoutStopSec=10s
    '';
   services.system-monitor = {
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
          };#end of system monitor
  }; #end of systemd

  users = {
    
    mutableUsers = false;
    users.root = {
      passwordFile = "/persistent/etc/pass-user-root";
      # openssh.authorizedKeys.keys = [
      #   ""
      # ];
    };
    users.nixos = {
      uid = 1000;
      #isNormalUser = true;
      passwordFile = "/persistent/etc/pass-user-nixos";
      # openssh.authorizedKeys.keys = [
      #   ""
      # ];
      home = "/home/nixos";
      group = "nixos";
      useDefaultShell = true;
      isSystemUser = true;
      extraGroups = [
        "wheel"
      ] ++ filterExistingGroups [
        "networkmanager"
      ];
      packages = with pkgs; [
       git tree wget curl nb htop screen tmux nload neovim vim emacs chromium firefox
     ];#end of packages
    }; #end of nixos user
   #users.groups.nixos = {};  
  };


  

  system.stateVersion = "23.05";

} // (import ./testhost-disko.nix { inherit lib; })
