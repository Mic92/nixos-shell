{ lib, pkgs, modulesPath, config, options, extendModules, ... }:

let
  isDarwin = options.virtualisation.host.pkgs.isDefined && config.virtualisation.host.pkgs.stdenv.hostPlatform.isDarwin;
in
{
  imports = [
    "${toString modulesPath}/virtualisation/qemu-vm.nix"
  ];

  options.nixos-shell = with lib; {
    inheritPath = mkOption {
      type = types.bool;
      default = options.virtualisation.host.pkgs.isDefined && config.virtualisation.host.pkgs.stdenv.hostPlatform == pkgs.stdenv.hostPlatform;
      description = "Whether to inherit the user's PATH.";
    };

    mounts = {
      mountHome = mkOption {
        type = types.bool;
        default = builtins.getEnv "HOME" != "";
        description = "Whether to mount `$HOME`.";
      };

      mountHomeReadOnly = mkOption {
        type = types.bool;
        default = false;
        description = "Mount `$HOME` read-only inside the VM.";
      };

      mountNixProfile = mkOption {
        type = types.bool;
        # if our host os does not match the guest os, binaries in our nix profile will not work
        default = options.virtualisation.host.pkgs.isDefined && config.virtualisation.host.pkgs.stdenv.hostPlatform == pkgs.stdenv.hostPlatform;
        description = "Whether to mount the user's nix profile.";
      };

      cache = mkOption {
        type = types.enum ["never" "auto" "always"];
        default = "auto";
        description = ''
          virtiofs cache mode used by virtiofsd for the shared directories.

          - `never`: no caching in the guest. Host changes are always visible
            immediately in the guest, at the cost of performance.
          - `auto`: metadata and data are cached in the guest but revalidated
            after a timeout, so host changes propagate to the guest with a
            small delay. This is the default and a good tradeoff.
          - `always`: the guest caches indefinitely. This is the fastest option
            but host changes are *not* propagated to the guest.
        '';
      };

      extraMounts = mkOption {
        type = types.attrsOf (types.coercedTo
          types.path (target: {
            inherit target;
          })
          (types.submodule ({ config, ... }: {
            options = {
              target = mkOption {
                type = types.path;
                description = lib.mdDoc "Target on the guest.";
              };

              tag = mkOption {
                type = types.str;
                internal = true;
              };
              readOnly = mkOption {
                type = types.bool;
                default = false;
                description = "Mount path read-only inside the VM.";
              };
            };

            config.tag = lib.mkDefault (
              builtins.substring 0 31 ( # tags must be shorter than 32 bytes
                "a" + # tags must not begin with a digit
                builtins.hashString "md5" config._module.args.name
              )
            );
          }))
        );
        default = {};
      };
    };

    terminfo.fixFSCaseConflicts = mkOption {
      type = types.bool;
      default = isDarwin;
      description = ''
        Whether to apply workaround for broken terminfo lookup on hosts with case insensitive file
        systems.
      '';
    };
  };

  config = let
    vmSystem = extendModules {
      modules = [
        ./nixos-shell-config.nix
      ];
    };
    inherit (vmSystem) config;
    hostPkgs = config.virtualisation.host.pkgs;
    cacheMode = config.nixos-shell.mounts.cache;
    vm = config.system.build.vm;
    in {
      system.build.nixos-shell =
        hostPkgs.runCommand
          vm.name
          {
            inherit (vm) meta;
            preferLocalBuild = true;
          }
          ''
            mkdir -p "$out/bin"
            ln -s '${config.system.build.toplevel}' "$out/system"
            runner=$(readlink -f '${vm}/bin/run-${config.system.name}-vm')
            substitute "$runner" "$out/bin/run-${config.system.name}-vm" \
              --replace-fail '--cache=always' '--cache=${cacheMode}'
            chmod +x "$out/bin/run-${config.system.name}-vm"
          '';
  };
}
