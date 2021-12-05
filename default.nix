{
  pkgs ? import <nixpkgs> {},
}:

with pkgs;
stdenv.mkDerivation {
  name = "nixos-shell";
  src = builtins.filterSource
    (path: type: baseNameOf path != "nixos.qcow2" &&
                 baseNameOf path != ".git" &&
                 baseNameOf path != ".direnv" &&
                 baseNameOf path != "result"
    ) ./.;
  nativeBuildInputs = [ makeWrapper ];
  preConfigure = ''
    export PREFIX=$out
  '';
  postInstall = ''
    wrapProgram $out/bin/nixos-shell \
      --prefix PATH : ${lib.makeBinPath [ jq coreutils gawk ]}
  '';
}
