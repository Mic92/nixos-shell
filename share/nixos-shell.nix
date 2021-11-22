{ nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
, configuration ? <nixos-config>

, flakeUri ? null
, flakeAttr ? null
}:
let
  nixos-shell = import ./modules/nixos-shell.nix;
  nixos-shell-config = import ./modules/nixos-shell-config.nix;

  flake = builtins.getFlake flakeUri;
  flakeSystem = flake.outputs.packages."${system}".nixosConfigurations."${flakeAttr}" or flake.outputs.nixosConfigurations."${flakeAttr}";
in
if flakeUri != null then
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
else
  import "${toString nixpkgs}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      configuration
      nixos-shell
      nixos-shell-config
    ];
  }
