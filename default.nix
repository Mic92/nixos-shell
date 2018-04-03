with import <nixpkgs> {};
stdenv.mkDerivation {
  name = "env";
  src = ./.;
  buildInputs = [ bash ];
  preConfigure = ''
    export PREFIX=$out
  '';
}
