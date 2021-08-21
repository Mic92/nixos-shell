{
  description = "Spawns lightweight nixos vms in a shell";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = inp:
  let
    lib = inp.nixpkgs.lib;
    supportedSystems = [ "x86_64-linux" ];
  in
  lib.foldl' lib.recursiveUpdate {} (lib.forEach supportedSystems (system: rec {

    packages."${system}".nixos-shell = import ./default.nix {
      pkgs = inp.nixpkgs.legacyPackages."${system}";
    };

    defaultPackage."${system}" = packages."${system}".nixos-shell;

  }));
}
