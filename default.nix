with import <nixpkgs> {};
stdenv.mkDerivation {
  name = "nixos-shell";
  src = ./.;
  buildInputs = [ bash ];
  preConfigure = ''
    export PREFIX=$out
  '';
}
