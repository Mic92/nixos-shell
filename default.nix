{
  pkgs ? import <nixpkgs> {},
}:

with pkgs;
stdenv.mkDerivation {
  name = "nixos-shell-${lib.fileContents ./version.txt}";
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
  postInstall = resholve.phraseSolution "nixos-shell" {
    scripts = [ "bin/nixos-shell" ];
    interpreter = lib.getExe bash;
    inputs = [ coreutils gawk jq ];
    fake.external = [ "nix" ];
    keep."$runScript" = true;
  };
}
