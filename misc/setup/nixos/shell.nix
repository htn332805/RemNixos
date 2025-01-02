with import <nixpkgs> {};

pkgs.mkShell {
  buildInputs = with pkgs; [
    (python3.withPackages (ps: with ps; [
      pyvisa
      pyvisa-py
      pyusb
      zeroconf
      psutil
    ]))
  ];
}

