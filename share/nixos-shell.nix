{ nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
, configuration ? <nixos-config>

, flakeStr ? null # flake as named on the command line
, flakeUri ? null
, flakeAttr ? null
}:
let
  lib = flake.inputs.nixpkgs.lib or (import nixpkgs { }).lib;

  defaultTo = default: e: if e == null then default else e;

  getFlakeOutput = path: lib.attrByPath path null flake.outputs;

  mkShellSystem = config: import "${if !(flakeUri == null) then (toString flake.inputs.nixpkgs) else (toString nixpkgs)}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      config
      ./modules/nixos-shell.nix
      ./modules/nixos-shell-config.nix
    ];
  };

  flake = builtins.getFlake flakeUri;

  flakeSystem = defaultTo
    (getFlakeOutput [ "nixosConfigurations" "${flakeAttr}" ])
    (getFlakeOutput [ "packages" "${system}" "nixosConfigurations" "${flakeAttr}" ]);

  flakeModule = getFlakeOutput [ "nixosModules" "${flakeAttr}" ];

  nixosShellModules = [
    ./modules/nixos-shell.nix
    ./modules/nixos-shell-config.nix
  ];
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
