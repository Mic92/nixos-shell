{ nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
, configuration ? <nixos-config>

, flakeUri ? null
, flakeAttr ? null
}:
let
  lib = (import nixpkgs { }).lib;

  nixos-shell = import ./modules/nixos-shell.nix;
  nixos-shell-config = import ./modules/nixos-shell-config.nix;

  defaultTo = default: e: if e == null then default else e;

  getFlakeOutput = path: lib.attrByPath path null flake.outputs;

  mkShellSystem = config: import "${toString nixpkgs}/nixos/lib/eval-config.nix" {
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

  nixosShellModules =
    if flakeSystem ? options.nixos-shell then
      [ nixos-shell-config ]
    else
      [ nixos-shell nixos-shell-config ];
in
if flakeUri != null then
  if flakeSystem != null then
    if flakeSystem ? "extendModules" then
      flakeSystem.extendModules { modules = nixosShellModules; }
    else
      flakeSystem.override (attrs: { modules = attrs.modules ++ nixosShellModules; })
  else if flakeModule != null then
    mkShellSystem flakeModule
  else
    throw "cannot find flake attribute '${flakeUri}#${flakeAttr}'"
else
  mkShellSystem configuration
