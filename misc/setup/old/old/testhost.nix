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
    kernelModules = [ "kvm-intel" "pktgen"];
    zfs.forceImportRoot = true;
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages; 
    supportedFilesystems = [ "zfs" "exfat" "ntfs" "ext2" "ext3" "ext4" "btrfs" "xfs" "squashfs" "fat16" "fat32" "hfs" "f2fs" "hfs+" "jfs" "linux-swap" "lvm" "lvm2" "lvm2 pv" "minix" "milfs2" "reiser4" "reiserfs" "udf" ]; 
    loader.efi.efiSysMountPoint = "/boot";
    loader.generationsDir.copyKernels = true;
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
    }; #end of loader
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
    firewall.allowedTCPPorts = [ 22 3389 5900 ];
  };

  environment = {
    variables = {
   	EDITOR = "vim";
  	}; #end of variables
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
	st xrdp x11vnc git vim wget curl firefox chromium neovim screen htop tmux emacs nb lynx links elinks mc gdu ripgrep fd fzf gcc gnumake cmake python3 nodejs nix-index nix-prefetch-git neofetch nixpkgs-fmt zsh nmap iperf3 fio sysstat ranger ncdu tree jq yg pandoc docker podman direnv starship oh-my-fish python3Packages.pip python3Packages.virtualenv libffi openssl minicom nix-diff nix-du nix-init nix-melt nix-output-monitor nix-tree nix-health nix-update poetry pyenv alacritty gptfdisk gparted parted gnumeric dwm xorg.xinit xorg.xorgserver xterm xfce.thunar xfce.xfce4-whiskermenu-plugin xlsx2csv sc-im grub2 refind coreutils nnn zip xz unzip p7zip eza mtr dnsutils ldns aria2 socat nmap ipcalc cowsay file which tree gnused gnutar gawk zstd gnupg hugo glow btop iftop nload iotop strace ltrace lsof lm_sensors ethtool pciutils usbutils
	(python3.withPackages (ps: with ps; [ jupyterlab pandas numpy pyvisa pyvisa-py pyusb zeroconf psutil ])) 
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

    xserver = {
	enable = true;
    	desktopManager = {
		xfce = {
			enable = true;
		}; #end of xfce  
	};#end of desktopmanager  
        windowManager = {
		qtile = {
			enable = true;
		}; #end of qtile
    		i3 = {
        		enable = true;
        		extraPackages = with pkgs; [
                		dmenu
                		i3status
                		i3lock
        		];#edn of extra package
		}; #end of i3
    		dwm = {
			enable = true;
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

  }; #end of services
  
security.sudo.extraConfig = ''
    # Rollback results in sudo lectures after each reboot
    Defaults lecture = never
  '';

  systemd = {
    enableEmergencyMode = false;

    # Explicitly disable ZFS mount service since we rely on legacy mounts
    services.zfs-mount.enable = false;

    extraConfig = ''
      DefaultTimeoutStartSec=20s
      DefaultTimeoutStopSec=10s
    '';
  };

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
  };

  system.stateVersion = "24.05";

} // (import ./testhost-disko.nix { inherit lib; })
