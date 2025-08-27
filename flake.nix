{
  description = "Spawns lightweight nixos vms in a shell";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs =
    inp:
    let
      lib = inp.nixpkgs.lib;

      inherit (lib)
        mapAttrs'
        removeSuffix
        makeOverridable
        nixosSystem
        mapAttrs
        ;

      vms =
        mapAttrs'
          (file: type: {
            name = removeSuffix ".nix" file;
            value = import (./examples + "/${file}");
          })
          (
            lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".nix" file) (
              builtins.readDir ./examples
            )
          );
      mkSystem =
        system: config:
        makeOverridable nixosSystem {
          inherit system;
          modules = [
            config
            inp.self.nixosModules.nixos-shell
          ];
        };

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      nixosConfigurations =
        let
          # Generate configs for all supported systems
          configsForSystem = system: mapAttrs (name: config: mkSystem system config) vms;

          # Create configs with system suffix
          allConfigs = lib.foldl' (
            acc: system:
            let
              systemConfigs = configsForSystem system;
              renamedConfigs = mapAttrs (
                name: config: lib.nameValuePair "${name}-${system}" config
              ) systemConfigs;
            in
            acc // (lib.mapAttrs' (name: value: value) renamedConfigs)
          ) { } supportedSystems;

          # Get x86_64-linux configs for the broken test config
          x86Configs = configsForSystem "x86_64-linux";
        in
        allConfigs
        // {
          # Used for testing that nixos-shell exits nonzero when provided a
          # non-extensible config
          BROKEN-DO-NOT-USE-UNLESS-YOU-KNOW-WHAT-YOU-ARE-DOING = removeAttrs x86Configs.vm [
            "extendModules"
            "override"
          ];
        };

      nixosModules.nixos-shell.imports = [ ./share/modules/nixos-shell.nix ];
    }
    // lib.foldl' lib.recursiveUpdate { } (
      lib.forEach supportedSystems (
        system:
        let
          pkgs = inp.nixpkgs.legacyPackages."${system}";

          # Define packages for this system
          packages = {
            nixos-shell = import ./default.nix { inherit pkgs; };
            default = inp.self.packages."${system}".nixos-shell;
          };

          # Define checks for this system
          checks =
            let
              # Check all nixosConfigurations that can build on this system
              nixosChecks =
                lib.mapAttrs' (name: config: lib.nameValuePair "nixos-${name}" config.config.system.build.toplevel)
                  (
                    lib.filterAttrs (
                      name: config:
                      # Only include configs that match current system based on name suffix
                      lib.hasSuffix "-${system}" name
                    ) inp.self.nixosConfigurations
                  );

              # Check packages
              packageChecks = lib.mapAttrs' (name: package: lib.nameValuePair "package-${name}" package) packages;
            in
            nixosChecks // packageChecks;
        in
        {
          packages."${system}" = packages;
          checks."${system}" = checks;
        }
      )
    );
}
