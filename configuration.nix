{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable XFCE and Qtile
  services.xserver.displayManager.defaultSession = "none+qtile";
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.windowManager.qtile.enable = true;

  # Configure Qtile
  services.xserver.windowManager.qtile.configFile = pkgs.writeText "config.py" ''
    from libqtile import bar, layout, widget
    from libqtile.config import Click, Drag, Group, Key, Match, Screen
    from libqtile.lazy import lazy

    mod = "mod4"

    keys = [
        Key([mod], "h", lazy.layout.left()),
        Key([mod], "l", lazy.layout.right()),
        Key([mod], "j", lazy.layout.down()),
        Key([mod], "k", lazy.layout.up()),
        Key([mod], "space", lazy.layout.next()),
        Key([mod, "shift"], "Return", lazy.layout.toggle_split()),
        Key([mod], "Return", lazy.spawn("xfce4-terminal")),
        Key([mod], "Tab", lazy.next_layout()),
        Key([mod], "w", lazy.window.kill()),
        Key([mod, "control"], "r", lazy.restart()),
        Key([mod, "control"], "q", lazy.shutdown()),
        Key([mod], "r", lazy.spawncmd()),
    ]

    groups = [Group(i) for i in "123456789"]

    layouts = [
        layout.Columns(border_focus_stack=["#d75f5f", "#8f3d3d"], border_width=4),
        layout.Max(),
        layout.Stack(num_stacks=2),
        layout.Bsp(),
        layout.Matrix(),
        layout.MonadTall(),
        layout.MonadWide(),
        layout.RatioTile(),
        layout.Tile(),
        layout.TreeTab(),
        layout.VerticalTile(),
        layout.Zoomy(),
    ]

    widget_defaults = dict(
        font="sans",
        fontsize=12,
        padding=3,
    )
    extension_defaults = widget_defaults.copy()

    screens = [
        Screen(
            top=bar.Bar(
                [
                    widget.CurrentLayout(),
                    widget.GroupBox(),
                    widget.Prompt(),
                    widget.WindowName(),
                    widget.Systray(),
                    widget.Clock(format="%Y-%m-%d %a %I:%M %p"),
                    widget.QuickExit(),
                    widget.CPU(),
                    widget.Memory(),
                    widget.Net(),
                    widget.Volume(),
                    widget.Battery(),
                ],
                24,
            ),
        ),
    ]

    # Drag floating layouts.
    mouse = [
        Drag([mod], "Button1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
        Drag([mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()),
        Click([mod], "Button2", lazy.window.bring_to_front()),
    ]

    dgroups_key_binder = None
    dgroups_app_rules = []  # type: list
    follow_mouse_focus = True
    bring_front_click = False
    cursor_warp = False
    floating_layout = layout.Floating(
        float_rules=[
            *layout.Floating.default_float_rules,
            Match(wm_class="confirmreset"),  # gitk
            Match(wm_class="makebranch"),  # gitk
            Match(wm_class="maketag"),  # gitk
            Match(wm_class="ssh-askpass"),  # ssh-askpass
            Match(title="branchdialog"),  # gitk
            Match(title="pinentry"),  # GPG key password entry
        ]
    )
    auto_fullscreen = True
    focus_on_window_activation = "smart"
    reconfigure_screens = True

    # If things like steam games want to auto-minimize themselves when losing
    # focus, should we respect this or not?
    auto_minimize = True

    # When using the Wayland backend, this can be used to configure input devices.
    wl_input_rules = None

    # XXX: Gasp! We're lying here. In fact, nobody really uses or cares about this
    # string besides java UI toolkits; you can see several discussions on the
    # mailing lists, GitHub issues, and other WM documentation that suggest setting
    # this string if your java app doesn't work correctly. We may as well just lie
    # and say that we're a working one by default.
    #
    # We choose LG3D to maximize irony: it is a 3D non-reparenting WM written in
    # java that happens to be on java's whitelist.
    wmname = "LG3D"
  '';

  # Enable SSHD
  services.openssh.enable = true;

  # Enable XRDP and VNC
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "qtile";
  services.x11vnc = {
    enable = true;
    auth = "/home/youruser/.Xauthority";
    autoStart = true;
    shared = true;
  };

  # Enable Nginx
  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      root = "/var/www/localhost";
    };
  };

  # Create a script to update the index.html
  systemd.services.update-index-html = {
    description = "Update index.html with system information";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      ${pkgs.bash}/bin/bash -c '
        echo "<html><body><pre>" > /var/www/localhost/index.html
        echo "HTOP Output:" >> /var/www/localhost/index.html
        ${pkgs.htop}/bin/htop -C | ${pkgs.coreutils}/bin/head -n 20 >> /var/www/localhost/index.html
        echo "\nDisk Usage:" >> /var/www/localhost/index.html
        ${pkgs.coreutils}/bin/df -hT >> /var/www/localhost/index.html
        echo "\nIO Statistics:" >> /var/www/localhost/index.html
        ${pkgs.sysstat}/bin/iostat >> /var/www/localhost/index.html
        echo "\nNetwork Load:" >> /var/www/localhost/index.html
        ${pkgs.nload}/bin/nload -t 1000 | ${pkgs.coreutils}/bin/head -n 10 >> /var/www/localhost/index.html
        echo "</pre></body></html>" >> /var/www/localhost/index.html
      '
    '';
  };

  # Run the update script every 5 minutes
  systemd.timers.update-index-html = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      Unit = "update-index-html.service";
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    vim
    wget
    firefox
    git
    vscode
    htop
    sysstat
    nload
  ];

  # Enable sound
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Define a user account
  users.users.youruser = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Edit this to match your NixOS version
}
