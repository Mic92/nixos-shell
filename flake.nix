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
      modules = [ config inp.self.nixosModules.nixos-shell ];
    };

    supportedSystems = [ "x86_64-linux" ];
  in
  {
    nixosConfigurations =
      let
        configs = mapAttrs (_name: config: mkSystem inp.nixpkgs config) vms;
      in
      configs
      //
      {
        # Used for testing that nixos-shell exits nonzero when provided a
        # non-extensible config
        BROKEN-DO-NOT-USE-UNLESS-YOU-KNOW-WHAT-YOU-ARE-DOING =
          removeAttrs configs.vm [ "extendModules" "override" ];
      };

    nixosModules.nixos-shell.imports = [ ./share/modules/nixos-shell.nix ];
  }

  //

  lib.foldl' lib.recursiveUpdate {} (lib.forEach supportedSystems (system: {

    packages."${system}" = {
      nixos-shell = import ./default.nix {
        pkgs = inp.nixpkgs.legacyPackages."${system}";
      };

      default = inp.self.packages."${system}".nixos-shell;
    };

  }));
}
