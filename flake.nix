{
  description = "Spawns lightweight nixos vms in a shell";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = inp:
  let
    lib = inp.nixpkgs.lib;

    inherit (lib) mapAttrs' removeSuffix makeOverridable nixosSystem mapAttrs;

    vms = mapAttrs' (file: _: {
      name = removeSuffix ".nix" file;
      value = import (./examples + "/${file}");
    }) (builtins.readDir ./examples);

    mkSystem = pkgs: config: makeOverridable nixosSystem {
      system = "x86_64-linux";
      modules = [ config  inp.self.nixosModules.nixos-shell ];
    };

    supportedSystems = [ "x86_64-linux" ];
  in
  {
    nixosConfigurations = mapAttrs (_name: config: mkSystem inp.nixpkgs config) vms;

    nixosModules.nixos-shell = import ./share/modules/nixos-shell.nix;
  }

  //

  lib.foldl' lib.recursiveUpdate {} (lib.forEach supportedSystems (system: rec {

    packages."${system}".nixos-shell = import ./default.nix {
      pkgs = inp.nixpkgs.legacyPackages."${system}";
    };

    defaultPackage."${system}" = packages."${system}".nixos-shell;

  }));
}
