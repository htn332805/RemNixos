#!/usr/bin/env bash

#
# NixOS install script synthesized from:
#
#   - Erase Your Darlings (https://grahamc.com/blog/erase-your-darlings)
#   - ZFS Datasets for NixOS (https://grahamc.com/blog/nixos-on-zfs)
#   - NixOS Manual (https://nixos.org/nixos/manual/)
#
# It expects the name of the block device (e.g. 'sda') to partition
# and install NixOS on and an authorized public ssh key to log in as
# 'root' remotely. The script must also be executed as root.
#
# Example: `sudo ./install.sh sde "ssh-rsa AAAAB..."`
#

set -euo pipefail

################################################################################

export COLOR_RESET="\033[0m"
export RED_BG="\033[41m"
export BLUE_BG="\033[44m"

function err {
    echo -e "${RED_BG}$1${COLOR_RESET}"
}

function info {
    echo -e "${BLUE_BG}$1${COLOR_RESET}"
}

################################################################################

export DISK=$1
export AUTHORIZED_SSH_KEY=$2

if ! [[ -v DISK ]]; then
    err "Missing argument. Expected block device name, e.g. 'sda'"
    exit 1
fi

export DISK_PATH="/dev/${DISK}"

if ! [[ -b "$DISK_PATH" ]]; then
    err "Invalid argument: '${DISK_PATH}' is not a block special file"
    exit 1
fi

if ! [[ -v AUTHORIZED_SSH_KEY ]]; then
    err "Missing argument. Expected public SSH key, e.g. 'ssh-rsa AAAAB...'"
    exit 1
fi

if [[ "$EUID" > 0 ]]; then
    err "Must run as root"
    exit 1
fi

export ZFS_POOL="vmpool"

# ephemeral datasets
export ZFS_LOCAL="${ZFS_POOL}/local"
export ZFS_DS_ROOT="${ZFS_LOCAL}/root"
export ZFS_DS_NIX="${ZFS_LOCAL}/nix"

# persistent datasets
export ZFS_SAFE="${ZFS_POOL}/safe"
export ZFS_DS_HOME="${ZFS_SAFE}/home"
export ZFS_DS_PERSIST="${ZFS_SAFE}/persist"

export ZFS_BLANK_SNAPSHOT="${ZFS_DS_ROOT}@blank"

################################################################################

info "Running the UEFI (GPT) partitioning and formatting directions from the NixOS manual ..."
# Create a protective MBR and GPT table
parted "$DISK_PATH" -- mklabel gpt
# Create DISK_PART_BOOT as the first partition (ESP)
parted "$DISK_PATH" -- mkpart ESP fat32 1MiB 513MiB
parted "$DISK_PATH" -- set 1 boot on
# Create DISK_PART_BIOS as the second partition
parted "$DISK_PATH" -- mkpart primary 513MiB 521MiB
parted "$DISK_PATH" -- set 2 bios_grub on
# Create DISK_PART_ROOT as the third partition
parted "$DISK_PATH" -- mkpart primary 521MiB 100%
# Export partition variables
export DISK_PART_BOOT="${DISK_PATH}1"
export DISK_PART_BIOS="${DISK_PATH}2"
export DISK_PART_ROOT="${DISK_PATH}3"

export BOOT="${DISK_PATH}1"
export BOOT_DISK_UUID="$(blkid --match-tag UUID --output value $BOOT)"
export BOOT_PARTUUID="$(blkid --match-tag PARTUUID --output value $BOOT)"

#parted "$DISK_PATH" -- mklabel gpt
#parted "$DISK_PATH" -- mkpart primary 1MiB 9MiB
#parted "$DISK_PATH" -- set 1 bios_grub on
#parted "$DISK_PATH" -- mkpart ESP fat32 9MiB 521MiB
#parted "$DISK_PATH" -- set 2 boot on
#parted "$DISK_PATH" -- mkpart primary 521MiB 100%
#export DISK_PART_BIOS="${DISK_PATH}1"
#export DISK_PART_BOOT="${DISK_PATH}2"
#export DISK_PART_ROOT="${DISK_PATH}3"

info "Formatting boot partition ..."
mkfs.fat -F 32 -n EFI "$DISK_PART_BOOT"

info "Creating '$ZFS_POOL' ZFS pool for '$DISK_PART_ROOT' ..."
zpool create -f "$ZFS_POOL" "$DISK_PART_ROOT"

info "Enabling compression for '$ZFS_POOL' ZFS pool ..."
zfs set compression=on "$ZFS_POOL"
zpool set autoexpand=on "$ZFS_POOL"

info "Creating '$ZFS_DS_ROOT' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_ROOT"

info "Configuring extended attributes setting for '$ZFS_DS_ROOT' ZFS dataset ..."
zfs set xattr=sa "$ZFS_DS_ROOT"

info "Configuring access control list setting for '$ZFS_DS_ROOT' ZFS dataset ..."
zfs set acltype=posixacl "$ZFS_DS_ROOT"

info "Creating '$ZFS_BLANK_SNAPSHOT' ZFS snapshot ..."
zfs snapshot "$ZFS_BLANK_SNAPSHOT"

info "Mounting '$ZFS_DS_ROOT' to /mnt ..."
mount -t zfs "$ZFS_DS_ROOT" /mnt

info "Mounting '$DISK_PART_BOOT' to /mnt/boot ..."
mkdir /mnt/boot
mkdir /mnt/efi
mkdir /mnt/boot/efi
mount -t vfat "$DISK_PART_BOOT" /mnt/boot
mkdir -p /mnt/boot/efi/EFI/refind
cp refind_x64.efi /mnt/boot/efi/EFI/refind
#zfs create -o mountpoint=none "${ZFS_POOL}/ubuntu"
#zfs create -o mountpoint=/ "${ZFS_POOL}/ubuntu/root"
#zfs create -o mountpoint=/home "${ZFS_POOL}/ubuntu/home"
#zfs create -V 50M -o volmode=dev "${ZFS_POOL}/ubuntu/fake_efi"
#gdisk "/dev/zvol/${ZFS_POOL}/ubuntu/fake_efi"
#mkfs.vfat -F32  "/dev/zvol/${ZFS_POOL}/ubuntu/fake_efi"

info "Creating '$ZFS_DS_NIX' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_NIX"

info "Disabling access time setting for '$ZFS_DS_NIX' ZFS dataset ..."
zfs set atime=off "$ZFS_DS_NIX"

info "Mounting '$ZFS_DS_NIX' to /mnt/nix ..."
mkdir /mnt/nix
mount -t zfs "$ZFS_DS_NIX" /mnt/nix

info "Creating '$ZFS_DS_HOME' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_HOME"

info "Mounting '$ZFS_DS_HOME' to /mnt/home ..."
mkdir /mnt/home
mount -t zfs "$ZFS_DS_HOME" /mnt/home

info "Creating '$ZFS_DS_PERSIST' ZFS dataset ..."
zfs create -p -o mountpoint=legacy "$ZFS_DS_PERSIST"

info "Mounting '$ZFS_DS_PERSIST' to /mnt/persist ..."
mkdir /mnt/persist
mount -t zfs "$ZFS_DS_PERSIST" /mnt/persist

info "Permit ZFS auto-snapshots on ${ZFS_SAFE}/* datasets ..."
zfs set com.sun:auto-snapshot=true "$ZFS_DS_HOME"
zfs set com.sun:auto-snapshot=true "$ZFS_DS_PERSIST"

info "Creating persistent directory for host SSH keys ..."
mkdir -p /mnt/persist/etc/ssh

info "Generating NixOS configuration (/mnt/etc/nixos/*.nix) ..."
nixos-generate-config --root /mnt

info "Enter password for the root user ..."
ROOT_PASSWORD_HASH="$(mkpasswd -m sha-512 | sed 's/\$/\\$/g')"

info "Enter personal user name ..."
read USER_NAME

info "Enter password for '${USER_NAME}' user ..."
USER_PASSWORD_HASH="$(mkpasswd -m sha-512 | sed 's/\$/\\$/g')"

info "Moving generated hardware-configuration.nix to /persist/etc/nixos/ ..."
mkdir -p /mnt/persist/etc/nixos
mv /mnt/etc/nixos/hardware-configuration.nix /mnt/persist/etc/nixos/

info "Backing up the originally generated configuration.nix to /persist/etc/nixos/configuration.nix.original ..."
mv /mnt/etc/nixos/configuration.nix /mnt/persist/etc/nixos/configuration.nix.original

info "Backing up the this installer script to /persist/etc/nixos/install.sh.original ..."
cp "$0" /mnt/persist/etc/nixos/install.sh.original

export BOOT="${DISK_PATH}1"
export BOOT_DISK_UUID="$(blkid --match-tag UUID --output value $BOOT)"
export BOOT_PARTUUID="$(blkid --match-tag PARTUUID --output value $BOOT)"

info "Writing NixOS configuration to /persist/etc/nixos/ ..."
cat <<EOF > /mnt/persist/etc/nixos/bootloader.nix
{ config, lib, pkgs, ... }:

{
# Use the systemd-boot EFI boot loader
  #boot.loader.systemd-boot.enable = true;
  #boot.loader.efi.canTouchEfiVariables = true;
  #boot.loader.efiSysMountPoint = '/efi'

  boot = {
    supportedFilesystems = [ "ext2" "ext3" "btrfs" "reiserfs" "jfs" "hfs+" "iso9660" "cpio" "affs" "zfs"  "ext4"  "btrfs"  "xfs"  "ntfs"  "vfat"  "exfat"  "hfs"  "hfsplus" ];
    loader = {
      timeout = 45;
      efi = {
        canTouchEfiVariables = true;
        #canTouchEfiVariables = false;  #for BIOS
        efiSysMountPoint = "/boot";
      };    #end efi bracket
      grub = {
        enable = true;
	useOSProber = true;
	version = 2;
        efiSupport = true;
	zfsSupport = true;
	forceInstall = true;
	#efiInstallAsRemovable = true;
	#extraFiles = {
  	#	"x86_64-efi/modinfo.sh" = "\${pkgs.grub2}/lib/grub/x86_64-efi/modinfo.sh";
	#	};
        #devices = [ "nodev" ];
        #device = "nodev";
	device =  "${DISK_PATH}" ;
	extraEntries = ''
		menuentry "rEFInd" {
			insmod part_gpt
			insmod fat
			insmod chain
			search --no-floppy --fs-uuid --set=root ${BOOT_PARTUUID} 
			chainloader /EFI/refind/refind_x64.efi
		}
	'';
	default = "rEFInd";
		}; #end grub bracket
    # Fallback to legacy BIOS if UEFI fails
    grub.forcei686 = lib.mkIf (!config.boot.loader.grub.efiSupport) true;
    }; #end loader
    zfs = {
      requestEncryptionCredentials = true;
      forceImportRoot = false;
    };
  kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
  kernelModules = [ "pktgen"  "vboxsf" "vboxguest" "vboxvideo" ];
  kernelParams = [ "systemd.log_level=debug" 
	"systemd.log_target=console" 
	"vga=normal" 
	"nomodeset" 
	"elevator=none" 
	"verbose" 
	"debug" 
	"net.ifnames=0" 
	"audit=0" 
	"copytoram" 
	"ipv6.disable=1" 
	"console=tty0" 
	"systemd.unit=multi-user.target" 
	"console=ttyS0,115200" ];
  initrd.postDeviceCommands = lib.mkAfter ''
  zfs rollback -r ${ZFS_BLANK_SNAPSHOT}
'';
  };  #end boot bracket 
  # Generate boot menu automatically
  boot.loader.grub.configurationLimit = 50; 
}

EOF

cat <<EOF > /mnt/persist/etc/nixos/packages.nix
{ config, lib, pkgs, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    	git
	linuxHeaders
	linux.dev
    	vim
   	wget
    	firefox
	chromium
	curl
	neovim
	screen
	htop
	tmux
	emacs
	nb
	lynx
	links2
	elinks
	mc
	gdu
	ripgrep
	fd
	fzf
	gcc
	gnumake
	cmake
	python3
	nnn
	mc
	mtr
	iperf3
	dnsutils
	ldns
	aria2
	socat
	ipcalc
	cowsay
	file
	which
 	gnused
	gnutar
	gawk
	zstd
	gnupg	
	zip
	xz
	unzip
	p7zip
	eza #modern ls	
	nodejs
	nix-index
	nix-prefetch-git
	neofetch
	nixpkgs-fmt
	zsh
	nmap
	iperf
	fio
	lm_sensors
	ethtool
	pciutils
	usbutils
	sysstat
	ranger
	ncdu
	tree
	jq
	yq
	pandoc
	docker
	podman
	direnv
	starship
	oh-my-fish
	python3Packages.pip
	python3Packages.virtualenv
	libffi
	openssl
	minicom
	nix-diff
	nix-du
	nix-init
	nix-melt
	nix-output-monitor
	nix-tree
	nix-health
	nix-update
	poetry
	pyenv
	hugo
	glow
	btop
	iotop
	iftop
	strace
	ltrace
	lsof
	dmidecode
	msr	
	alacritty
	gptfdisk
	gparted
	parted
	nload
	gnumeric
	dwm
	xorg.xinit
	xorg.xorgserver
	xterm
	xrdp
	x11vnc
	xfce.thunar
	xfce.xfce4-whiskermenu-plugin
	xlsx2csv
	sc-im
	grub2
	refind
	(python3.withPackages (ps: with ps; [
      		dash scipy matplotlib ipython pytest
      		jupyterlab
      		pandas
      		numpy
      		# Add other Python packages here
    		])) #end python3 parenthesis
	
  ]; # end of with pkgs
  programs = {
  	mtr.enable = true;
  	gnupg.agent = {
    		enable = true;
    		enableSSHSupport = true;
  		}; #end of gnupg
	}; #end of programs
}
EOF

cat <<EOF > /mnt/persist/etc/nixos/services.nix
{ config, lib, pkgs, ... }:

{
  services = {
	libinput.enable = true;
    	displayManager.defaultSession = "xfce";
  	pipewire = {
   		enable = true;
    		pulse.enable = false;
  		}; # end pipewire

  	zfs = {
    		autoScrub.enable = true;
    		autoSnapshot.enable = true;
  		}; #end of zfs

  	openssh = {
    		enable = true;
    		settings = {
      			PermitRootLogin = "yes";
      			PasswordAuthentication = true;
			X11Forwarding = true;
    			}; #end of setting
    		hostKeys = [
      			{
        	  	  path = "/persist/etc/ssh/ssh_host_ed25519_key";
        	  	  type = "ed25519";
      			}
      			{
        	  	  path = "/persist/etc/ssh/ssh_host_rsa_key";
        	 	  type = "rsa";
       		  	  bits = 4096;
      			}
    		]; #end of hostkeys
  	}; #end of openssh

  	xserver = {
    		enable = true;
    		autorun = true;
    		xkb.layout = "us";
    		displayManager = {
      			startx.enable = true;
      			lightdm.enable = true;
    			}; #end of display
    		desktopManager.xfce.enable = true;
    		windowManager = {
      			i3 = {
        			enable = true;
       	 			extraPackages = with pkgs; [
          				dmenu
          				i3status
          				i3lock
        				]; #end of extrapackages
      				}; #end of i3
      			qtile.enable = true;
      			dwm.enable = true;
    			}; # end of windows manager
  		}; #end of xserver

  	xrdp = {
    		enable = true;
    		defaultWindowManager = "startxfce4";
  	}; #end of xrdp
   }; #end of services

   systemd.services.x11vnc = {
  	description = "x11vnc remote desktop server";
  	after = [ "display-manager.service" ];
  	wantedBy = [ "multi-user.target" ];
  	serviceConfig = {
    		ExecStart = "\${pkgs.x11vnc}/bin/x11vnc -display :0 -auth /home/nixos/.Xauthority -forever -loop -noxdamage -repeat -rfbauth /etc//x11vnc.pass -rfbport 5900 -shared";
    		Restart = "on-failure";
  	}; #end of serviceconfig
    }; # end of systemd.services
}
EOF

cat <<EOF > /mnt/persist/etc/nixos/networking.nix
{ config, lib, pkgs, ... }:

{
  networking = {
    hostName = "nixos";
    hostId = "$(head -c 8 /etc/machine-id)";
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 22 3389 5900 ];
  };
}
EOF

cat <<EOF > /mnt/persist/etc/nixos/users.nix
{ config, lib, pkgs, ... }:

{
  # Define a user account
  users = {
  	mutableUsers = false;
  	users = {
    		root = {
     			initialHashedPassword = "${ROOT_PASSWORD_HASH}";
    		}; #end root
    		${USER_NAME} = {
      			createHome = true;
    			#isNormalUser = true;
     		 	initialHashedPassword = "${USER_PASSWORD_HASH}";
      			extraGroups = [ "wheel" "vboxsf" "networkmanager" ];
      			group = "users";
     		 	uid = 1000;
     	 		home = "/home/${USER_NAME}";
      			useDefaultShell = true;
      			isSystemUser = true;
      			openssh.authorizedKeys.keys = [ "${AUTHORIZED_SSH_KEY}" ];
			packages = with pkgs; [
      				firefox
    				#  thunderbird
    			]; #end of packages
    		}; # end USER_NAME
  	}; #end of users
  }; #end of outside users

  security.sudo.wheelNeedsPassword = false;
}
EOF

cat <<EOF > /mnt/persist/etc/nixos/flake.nix
{ config, pkgs, lib, ... }:
{
  description = "A simple NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    helix.url = "github:helix-editor/helix/master";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
	home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            # TODO replace ryan with your own username
            home-manager.users.i${USER_NAME} = import ./home.nix;

          }
      ];
    };
  };
}
EOF

cat <<EOF > /mnt/persist/etc/nixos/home.nix
{ config, pkgs, lib, ... }:
{
  # TODO please change the username & home directory to your own
  home.username = "${USER_NAME}";
  home.homeDirectory = "/home/${USER_NAME}";

  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [

    neofetch
    nnn 
    htop
    screen
    tmux
    gdu
    zip
    xz
    unzip
    p7zip
    ripgrep 
    jq 
    yq-go 
    eza 
    fzf 
    mtr 
    iperf3
    dnsutils 
    ldns
    aria2 
    socat 
    nmap 
    ipcalc  
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg
    nix-output-monitor
    hugo 
    glow 
    btop  
    iotop 
    iftop 
    strace 
    ltrace 
    lsof 
    sysstat
    lm_sensors 
    ethtool
    pciutils 
    usbutils 
  ];

  # starship - an customizable prompt for any shell
  programs.starship = {
    enable = true;
    # custom settings
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  # alacritty - a cross-platform, GPU-accelerated terminal emulator
  programs.alacritty = {
    enable = true;
    # custom settings
    settings = {
      env.TERM = "xterm-256color";
      font = {
        size = 12;
        draw_bold_text_with_bright_colors = true;
      };
      scrolling.multiplier = 5;
      selection.save_to_clipboard = true;
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    # TODO add your custom bashrc here
    bashrcExtra = ''
      export PATH="\$PATH:\$HOME/bin:\$HOME/.local/bin:$HOME/go/bin"
    '';

    # set some aliases, feel free to add more or remove some
    shellAliases = {
      k = "kubectl";
      urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
      urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
    };
  };

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}
EOF

cat <<EOF > /mnt/persist/etc/nixos/configuration.nix
{ config, pkgs, lib, ... }:
let
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in
{
  imports =
    [ 
      ./hardware-configuration.nix
      ./users.nix
      ./networking.nix
      ./packages.nix
      ./services.nix
      ./bootloader.nix
	"\${impermanence}/nixos.nix"
    ];
  nix.nixPath =
    [
      "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
      "nixos-config=/persist/etc/nixos/configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];
  # Set your time zone
  time.timeZone = "America/Los_Angeles";
  # Enable sound
  sound.enable = true;
  nix.settings.sandbox = false;
  hardware.pulseaudio.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
  	font = "Lat2-Terminus16";
  	useXkbConfig = true;
	}; #end console
  virtualisation.virtualbox.guest.enable = true;

  nix.settings = {
	# Enable the Flakes feature and the accompanying new nix command-line tool
  	experimental-features = [ "nix-command" "flakes" ];
  	substituters = [
    		"https://cache.nixos.org/"
    		"https://nixcache.reflex-frp.org"
    		"https://cache.iog.io"
  		]; # end of substituters
  	connect-timeout = 15;
  	stalled-download-timeout = 90;
  	max-jobs = 1;
	}; #end of nix.settings

  system.activationScripts.x11vncpass = ''
  	\${pkgs.x11vnc}/bin/x11vnc -storepasswd haix11vnc /etc/x11vnc.pass
  '';

  # System-wide environment variables
  environment.variables = {
    	EDITOR = "nano";
  	};
  fileSystems."/persist" = {
  	device = "${ZFS_POOL}/safe/persist";
 	fsType = "zfs";
  	neededForBoot = true;
	};

  systemd.tmpfiles.rules = [
  	"L /etc/passwd - - - - /persist/etc/passwd"
	];

  environment.persistence."/persist" = {
  	directories = [
    		"/etc/nixos"
    		"/var/log"
    		"/var/lib/nixos"
    		"/etc"
  		];
	};
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "24.05";
  system.copySystemConfiguration = true;
}
EOF

info "Installing NixOS to /mnt ..."
ln -s /mnt/persist/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix
ln -s /mnt/persist/etc/nixos/users.nix /mnt/etc/nixos/users.nix
ln -s /mnt/persist/etc/nixos/home.nix /mnt/etc/nixos/home.nix
ln -s /mnt/persist/etc/nixos/flake.nix /mnt/etc/nixos/flake.nix
ln -s /mnt/persist/etc/nixos/networking.nix /mnt/etc/nixos/networking.nix
ln -s /mnt/persist/etc/nixos/packages.nix /mnt/etc/nixos/packages.nix
ln -s /mnt/persist/etc/nixos/services.nix /mnt/etc/nixos/services.nix
ln -s /mnt/persist/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hardware-configuration.nix
ln -s /mnt/persist/etc/nixos/bootloader.nix /mnt/etc/nixos/bootloader.nix
#MUST ADD THE PARTUUID BEFORE INSTALL
#need to run sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz home-manager and  sudo nix-channel --update then add "home-manager=/nix/var/nix/profiles/per-user/root/channels/home-manager" to config file
#nixos-install -I "nixos-config=/mnt/persist/etc/nixos/configuration.nix" --no-root-passwd  # already prompted for and configured password
