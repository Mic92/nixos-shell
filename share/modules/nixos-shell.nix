{ lib, modulesPath, ... }:

{
  imports = [
    "${toString modulesPath}/virtualisation/qemu-vm.nix"
  ];
  
  options.nixos-shell = with lib; {
    mounts = let
      cache = mkOption {
        type = types.enum ["none" "loose" "fscache" "mmap"];
        default = "loose"; # bad idea? Well, at least it is fast!1!!
        description = "9p caching policy";
      };
    in {
      mountHome = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to mount `/home`.";
      };

      mountNixProfile = mkOption {
        type = types.bool;
        default = true;
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
  };
}
