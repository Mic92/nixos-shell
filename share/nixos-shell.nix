{ nixpkgs ? <nixpkgs>
, guestSystem ? builtins.replaceStrings ["darwin"] ["linux"] builtins.currentSystem
, hostSystem ? builtins.currentSystem
, configuration ? <nixos-config>
, flakeStr ? null # flake as named on the command line
, flakeUri ? null
, flakeAttr ? null
}:
let
  hasFlake = flakeUri != null;
  hasFlakeNixpkgs = hasFlake && flake ? inputs.nixpkgs;

  flake = builtins.getFlake flakeUri;

  nixosShellModules = [
    ({lib, ...}: lib.optionalAttrs (guestSystem != hostSystem) {
      virtualisation.host.pkgs = if hasFlakeNixpkgs then
        flake.inputs.nixpkgs.legacyPackages.${hostSystem}
      else
        import nixpkgs { system = hostSystem; };
    })
    ./modules/nixos-shell.nix
    ./modules/nixos-shell-config.nix
  ];

  nixpkgsPath = if hasFlakeNixpkgs then
    flake.inputs.nixpkgs
  else
    nixpkgs;

  mkShellSystem = config: import "${toString nixpkgsPath}/nixos/lib/eval-config.nix" {
    system = guestSystem;
    modules = [ config ] ++ nixosShellModules;
  };

  flakeSystem =
    flake.outputs.packages.${guestSystem}.nixosConfigurations.${flakeAttr} or
    flake.outputs.nixosConfigurations.${flakeAttr} or
    null;

  flakeModule = flake.outputs.nixosModules.${flakeAttr} or null;

in
if flakeUri != null then
  if flakeSystem != null then
    if flakeSystem ? "extendModules" then
      flakeSystem.extendModules { modules = nixosShellModules; }
    else if flakeSystem ? "override" then
      flakeSystem.override (attrs: { modules = attrs.modules ++ nixosShellModules; })
    else
      throw ''
          '${flakeStr}#${flakeAttr}' is missing the expected 'override' attribute.

          Please ensure that '${flakeStr}#${flakeAttr}' is an overridable attribute set by declaring it with 'lib.makeOverridable'.

          For instance:

              nixosConfigurations = let
                lib = nixpkgs.lib;
              in {
                "${flakeAttr}" = lib.makeOverridable lib.nixosSystem {
                  # ...
                };
              };

          Alternatively, upgrade to a version of nixpkgs that provides the 'extendModules' function on NixOS system configurations.

          See https://github.com/Mic92/nixos-shell#start-a-virtual-machine for additional information.
      ''
  else if flakeModule != null then
    mkShellSystem flakeModule
  else
    throw "cannot find flake attribute '${flakeUri}#${flakeAttr}'"
else
  mkShellSystem configuration
