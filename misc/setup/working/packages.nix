{ config, pkgs, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    vim
    wget
    firefox
    git
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
	nodejs
	nix-index
	nix-prefetch-git
	neofetch
	nixpkgs-fmt
	zsh
	nmap
	iperf
	fio
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
	ipmitool
	refind
	(python3.withPackages (ps: with ps; [
      		dash scipy matplotlib ipython pytest
      		jupyterlab
      		pandas
      		numpy
      		# Add other Python packages here
    		])) #end python3 parenthesis
	
  ];
}
