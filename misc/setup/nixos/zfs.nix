{ config, lib, pkgs, ... }:

{
  imports =
    [ 
      #./shell.nix
    ];
  boot.supportedFilesystems = [ "zfs" "exfat" "ntfs" "ext2" "ext3" "ext4" "btrfs" "xfs" "squashfs" "fat16" "fat32" "hfs" "f2fs" "hfs+" "jfs" "linux-swap" "lvm" "lvm2" "lvm2 pv" "minix" "milfs2" "reiser4" "reiserfs" "udf" ];
  #networking.hostId = "b3e3e922";
  networking.hostId = "12345678";
  networking.hostName = "hainixos";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 3389 5900 ];
  networking = {
    useDHCP = false;
    interfaces.enp0s25 = {
      ipv4.addresses = [{
        address = "172.28.94.183";
        prefixLength = 24;
      }];
    };
    defaultGateway = "172.28.94.1";
    nameservers = [ "8.8.8.8" "8.8.4.4" ]; # You may want to adjust these
  };
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
   console = {
     font = "Lat2-Terminus16";
     keyMap = lib.mkDefault  "us";
     useXkbConfig = true; # use xkb.options in tty.
   };#end of console
  #BK PRECISION
  services.udev.extraRules = ''
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="ffff", ATTRS{idProduct}=="9206", GROUP="users", MODE="0666"
  '';
  # Enable the X11 windowing system.
  services.xserver.enable = true;
  # Configure keymap in X11
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.options = "eurosign:e,caps:escape";
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.windowManager.qtile.enable = true;
  services.xserver.windowManager.i3 = {
        enable = true;
        extraPackages = with pkgs; [
                dmenu
                i3status
                i3lock
        ];
  };#end of i3
  services.xserver.windowManager.dwm.enable = true;
  services.xserver.displayManager.defaultSession = "none+dwm";
  services.xserver.displayManager.lightdm.enable = true;
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "dwm";
  services.xrdp.openFirewall = true;
  # Enable CUPS to print documents.
  # services.printing.enable = true;
  # Enable sound.
  services.pipewire = {
     enable = true;
     pulse.enable = true;
   }; #end of pipewire
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nixos = {
     isNormalUser = true;
     extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
     packages = with pkgs; [
       git tree wget curl nb htop screen tmux nload neovim vim emacs chromium firefox
     ]; #end of nixos user config
   }; #enf of users config
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
     git st wget curl vim tree nb htop screen tmux nload gnumeric neovim emacs chromium firefox
     (python3.withPackages (ps: with ps; [
      pyvisa
      pyvisa-py
      pyusb
      zeroconf
      psutil
    ])) 
  ];
  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
  boot.zfs.devNodes = "/dev/disk/by-partlabel";
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    zfs rollback -r rpool/nixos@SYSINIT
  '';
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.generationsDir.copyKernels = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.copyKernels = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.zfsSupport = true;

  boot.loader.grub.device = "/dev/disk/by-id/wwn-0x55cd2e414d5b3608";
  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ata_piix" "ahci" "xhci_pci" "usbhid" "usb_storage" "sd_mod" "sr_mod"];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" "pktgen"];
  boot.extraModulePackages = [ ];
  # Disable hibernation
  boot.kernelParams = [ "nohibernate" ];
  # Disable sleep/suspend
  powerManagement.enable = false;
  boot.loader.grub.extraPrepareConfig = ''
    mkdir -p /boot/efis
    for i in  /boot/efis/*; do mount $i ; done

    mkdir -p /boot/efi
    mount /boot/efi
  '';

  boot.loader.grub.extraInstallCommands = ''
    ESP_MIRROR=$(mktemp -d)
    cp -r /boot/efi/EFI $ESP_MIRROR
    for i in /boot/efis/*; do
      cp -r $ESP_MIRROR/EFI $i
    done
    rm -rf $ESP_MIRROR
  '';

  boot.loader.grub.devices = [
    "/dev/sda"
  ];

users.users.root.initialHashedPassword = "$6$Ue79BJdd5n1DBk.V$OfnevjObMSCFcH0iYxkJET6J87Ahveef0rJ/jWJGHeW397GOSejjf5xlli0bhpFXjAVuuC8ex1YTAdD6Y.gKx.";
users.users.nixos.initialHashedPassword = "$6$Ue79BJdd5n1DBk.V$OfnevjObMSCFcH0iYxkJET6J87Ahveef0rJ/jWJGHeW397GOSejjf5xlli0bhpFXjAVuuC8ex1YTAdD6Y.gKx.";
  # Custom XRDP configuration
  environment.etc."xrdp/xrdp.ini".text = ''
    [Globals]
    ; xrdp.ini file version number
    ini_version=1

    ; fork a new process for each incoming connection
    fork=true

    ; ports to listen on, number alone means listen on all interfaces
    ; 0.0.0.0 or :: if ipv6 is configured
    ; space between multiple occurrences
    ;
    ; Examples:
    ;   port=3389
    ;   port=unix://./tmp/xrdp.socket
    ;   port=tcp://.:3389                           127.0.0.1:3389
    ;   port=tcp://:3389                            *:3389
    ;   port=tcp://<any ipv4 format addr>:3389      192.168.1.1:3389
    ;   port=tcp6://.:3389                          ::1:3389
    ;   port=tcp6://:3389                           *:3389
    ;   port=tcp6://{<any ipv6 format addr>}:3389   {FC00:0:0:0:0:0:0:1}:3389
    ;   port=vsock://<cid>:<port>
    port=3389

    ; 'port' above should be connected to with vsock instead of tcp
    ; use this only with number alone in port above
    ; prefer use vsock://<cid>:<port> above
    use_vsock=false

    ; regulate if the listening socket use socket option tcp_nodelay
    ; no buffering will be performed in the TCP stack
    tcp_nodelay=true

    ; regulate if the listening socket use socket option keepalive
    ; if the network connection disappear without close messages the connection will be closed
    tcp_keepalive=true

    ; set tcp send/recv buffer (for experts)
    #tcp_send_buffer_bytes=32768
    #tcp_recv_buffer_bytes=32768

    ; security layer can be 'tls', 'rdp' or 'negotiate'
    ; for client compatible layer
    security_layer=negotiate

    ; minimum security level allowed for client for classic RDP encryption
    ; use tls_ciphers to configure TLS encryption
    ; can be 'none', 'low', 'medium', 'high', 'fips'
    crypt_level=high

    ; X.509 certificate and private key
    ; openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 365
    certificate=
    key_file=

    ; set SSL protocols
    ; can be comma separated list of 'SSLv3', 'TLSv1', 'TLSv1.1', 'TLSv1.2', 'TLSv1.3'
    ssl_protocols=TLSv1.2, TLSv1.3
    ; set TLS cipher suites
    #tls_ciphers=HIGH

    ; Section name to use for automatic login if the client sends username
    ; and password. If empty, the domain name sent by the client is used.
    ; If empty and no domain name is given, the first suitable section in
    ; this file will be used.
    autorun=

    allow_channels=true
    allow_multimon=true
    bitmap_cache=true
    bitmap_compression=true
    bulk_compression=true
    #hidelogwindow=true
    max_bpp=32
    new_cursors=true
    ; fastpath - can be 'input', 'output', 'both', 'none'
    use_fastpath=both
    ; when true, userid/password *must* be passed on cmd line
    #require_credentials=true
    ; You can set the PAM error text in a gateway setup (MAX 256 chars)
    #pamerrortxt=change your password according to policy at http://url

    ; colors used by windows in RGB format
    blue=009cb5
    grey=dedede
    #black=000000
    #dark_grey=808080
    #blue=08246b
    #dark_blue=08246b
    #white=ffffff
    #red=ff0000
    #green=00ff00
    #background=626c72

    ; colors used by windows in RGB format
    ; 0x00000000 to 0x00ffffff
    ; black=000000
    ; grey=c0c0c0
    ; dark_grey=808080
    ; blue=0000ff
    ; dark_blue=00008b
    ; white=ffffff
    ; red=ff0000
    ; green=00ff00

    ;#tls_ciphers=HIGH
    #tls_ciphers=HIGH:!ADH:!SHA1:!AESCCM
    #autorun=xrdp1

    ; Some session types such as Xorg, X11rdp and Xvnc start a display server.
    ; Startup command-line parameters for the display server are configured
    ; in sesman.ini. See and configure also sesman.ini.
    [Xvnc]
    name=Xvnc
    lib=libvnc.so
    username=ask
    password=ask
    ip=127.0.0.1
    port=5900
    #xserverbpp=24
    #delay_ms=2000

    [Xorg]
    name=Xorg
    lib=libxup.so
    username=ask
    password=ask
    ip=127.0.0.1
    port=-1
    code=20

    [X11rdp]
    name=X11rdp
    lib=libxup.so
    username=ask
    password=ask
    ip=127.0.0.1
    port=-1
    xserverbpp=24
    code=10

    [console]
    name=console
    lib=libvnc.so
    ip=127.0.0.1
    port=5900
    username=na
    password=ask
    #delay_ms=2000

    [vnc-any]
    name=vnc-any
    lib=libvnc.so
    ip=ask
    port=ask5900
    username=na
    password=ask
    #pamusername=asksame
    #pampassword=asksame
    #pamsessionmng=127.0.0.1
    #delay_ms=2000

    [sesman-any]
    name=sesman-any
    lib=libvnc.so
    ip=ask
    port=-1
    username=ask
    password=ask
    #delay_ms=2000

    [neutrinordp-any]
    name=neutrinordp-any
    lib=libxrdpneutrinordp.so
    ip=ask
    port=ask3389
    username=ask
    
    ; You can override the common channel settings for each session type
    #channel.rdpdr=true
    #channel.rdpsnd=true
    #channel.drdynvc=true
    #channel.cliprdr=true
    #channel.rail=true
    #channel.xrdpvr=true
  '';

}
