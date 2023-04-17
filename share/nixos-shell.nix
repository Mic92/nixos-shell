{ nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
, configuration ? <nixos-config>

, flakeUri ? null
, flakeAttr ? null
}:
let
  lib = flake.inputs.nixpkgs.lib or (import nixpkgs { }).lib;

  nixos-shell = import ./modules/nixos-shell.nix;
  nixos-shell-config = import ./modules/nixos-shell-config.nix;

  defaultTo = default: e: if e == null then default else e;

  getFlakeOutput = path: lib.attrByPath path null flake.outputs;

  mkShellSystem = config: import "${toString flake.inputs.nixpkgs or nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      config
      nixos-shell
      nixos-shell-config
    ];
  };

  flake = builtins.getFlake flakeUri;

  flakeSystem = defaultTo
    (getFlakeOutput [ "nixosConfigurations" "${flakeAttr}" ])
    (getFlakeOutput [ "packages" "${system}" "nixosConfigurations" "${flakeAttr}" ]);

  flakeModule = getFlakeOutput [ "nixosModules" "${flakeAttr}" ];
in
if flakeUri != null then
  if flakeSystem != null then
    flakeSystem.override
      (attrs: {
        modules =
          let
            nixosShellModules =
              if flakeSystem ? options.nixos-shell then
                [ nixos-shell-config ]
              else
                [ nixos-shell nixos-shell-config ];
          in
          attrs.modules ++ nixosShellModules;
      })
  else if flakeModule != null then
    mkShellSystem flakeModule
  else
    throw "cannot find flake attribute '${flakeUri}#${flakeAttr}'"
else
  mkShellSystem configuration
