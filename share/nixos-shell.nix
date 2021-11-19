{
  nixpkgs ? <nixpkgs>
, system ? builtins.currentSystem
, configuration ? <nixos-config>

, flakeUri ? null
, flakeAttr ? null
}:
let 
  nixos-shell-module = import ./modules/nixos-shell.nix;

  flake = builtins.getFlake flakeUri;
  flakeSystem = flake.outputs.packages."${system}".nixosConfigurations."${flakeAttr}" or flake.outputs.nixosConfigurations."${flakeAttr}";
in
  if flakeUri != null then
    flakeSystem.override (attrs: {
      modules = attrs.modules ++ [ nixos-shell-module ];
    })
  else
    import "${toString nixpkgs}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        configuration
        nixos-shell-module
      ];
    }
