with import <nixpkgs> {};
stdenv.mkDerivation {
  name = "nixos-shell";
  src = builtins.filterSource
    (path: type: baseNameOf path != "nixos.qcow2" &&
                 baseNameOf path != ".git" &&
                 baseNameOf path != ".direnv" &&
                 baseNameOf path != "result"
    ) ./.;
  buildInputs = [ bash ];
  preConfigure = ''
    export PREFIX=$out
  '';
}
