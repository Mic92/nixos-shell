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

    mounts = let
      cache = mkOption {
        type = types.enum ["none" "loose" "fscache" "mmap"];
        default = "loose"; # bad idea? Well, at least it is fast!1!!
        description = "9p caching policy";
      };
    in {
      mountHome = mkOption {
        type = types.bool;
        default = builtins.getEnv "HOME" != "";
        description = "Whether to mount `$HOME`.";
      };

      mountNixProfile = mkOption {
        type = types.bool;
        # if our host os does not match the guest os, binaries in our nix profile will not work
        default = options.virtualisation.host.pkgs.isDefined && config.virtualisation.host.pkgs.stdenv.hostPlatform == pkgs.stdenv.hostPlatform;
        description = "Whether to mount the user's nix profile.";
      };

      inherit cache;

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

              inherit cache;

              tag = mkOption {
                type = types.str;
                internal = true;
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
  in {
    system.build.nixos-shell = vmSystem.config.system.build.vm;
  };
}
