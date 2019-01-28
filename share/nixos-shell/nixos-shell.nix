{ lib, config, pkgs, ... }:

let
  home = builtins.getEnv "HOME";
  user = builtins.getEnv "USER";
  pwd = builtins.getEnv "PWD";
  shell = builtins.getEnv "QEMU_SHELL";
  path = builtins.getEnv "QEMU_PATH";
  nixos_config = builtins.getEnv "QEMU_NIXOS_CONFIG";
  term = builtins.getEnv "TERM";
  cfg = config.nixos-shell;
in {
  imports = lib.optional (nixos_config != "") nixos_config ++ [
    <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>
  ];

  options.nixos-shell = with lib; {
    mounts = let
      cache = mkOption {
        type = types.enum ["none" "loose" "fscache" "mmap"];
        default = "loose"; # bad idea? Well, at least it is fast!1!!
      };
    in {
      mountHome = mkOption {
        type = types.bool;
        default = true;
      };

      mountNixProfile = mkOption {
        type = types.bool;
        default = true;
      };

      inherit cache;

      extraMounts = mkOption {
        type = types.attrsOf (types.submodule ({ config, ... }: {
          options = {
            target = mkOption {
              type = types.path;
            };

            inherit cache;

            tag = mkOption {
              type = types.str;
              internal = true;
            };
          };

          config.tag = lib.mkVMOverride (
            builtins.substring 0 31 ( # tags must be shorter than 32 bytes
              "a" + # tags must not begin with a digit
              builtins.hashString "md5" config._module.args.name
            )
          );
        }));
        default = {};
      };
    };
  };

  config = {
    users.extraUsers.root = {
      # Allow the user to login as root without password.
      initialHashedPassword = "";
      shell = lib.mkVMOverride pkgs.${builtins.baseNameOf (builtins.getEnv "SHELL")} or config.users.defaultUserShell;
      home = let
        home = builtins.getEnv "HOME";
      in lib.mkVMOverride (if home != "" && cfg.mounts.mountHome then home else "/root");
    };
    services.mingetty.helpLine = ''
      Log in as "root" with an empty password.
    '';

    virtualisation = {
      graphics = lib.mkVMOverride false;
      memorySize = lib.mkVMOverride "500M";

      qemu.options = let
        nixProfile = "/nix/var/nix/profiles/per-user/${user}/profile/";
      in
        lib.optional cfg.mounts.mountHome "-virtfs local,path=/home,security_model=none,mount_tag=home" ++
        lib.optional (cfg.mounts.mountNixProfile && builtins.pathExists nixProfile) "-virtfs local,path=${nixProfile},security_model=none,mount_tag=nixprofile" ++
        lib.mapAttrsToList (target: mount: "-virtfs local,path=${builtins.toString mount.target},security_model=none,mount_tag=${mount.tag}") cfg.mounts.extraMounts;
    };

    # build-vm overrides our filesystem settings in nixos-config
    boot.initrd.postMountCommands =
      (lib.optionalString cfg.mounts.mountHome ''
        mkdir -p $targetRoot/home/
        mount -t 9p home $targetRoot/home/ -o trans=virtio,version=9p2000.L,cache=${cfg.mounts.cache}
      '') +
      (lib.optionalString (user != "" && cfg.mounts.mountNixProfile) ''
        mkdir -p $targetRoot/nix/var/nix/profiles/per-user/${user}/profile/
        mount -t 9p nixprofile $targetRoot/nix/var/nix/profiles/per-user/${user}/profile/ -o trans=virtio,version=9p2000.L,cache=${cfg.mounts.cache}
      '') +
      builtins.concatStringsSep " " (lib.mapAttrsToList (target: mount: ''
        mkdir -p $targetRoot/${target}
        mount -t 9p ${mount.tag} $targetRoot/${target} -o trans=virtio,version=9p2000.L,cache=${mount.cache}
      '') cfg.mounts.extraMounts);

    environment = {
      systemPackages = with pkgs; [
        xterm # for resize command
      ];

      loginShellInit = ''
        # fix terminal size
        eval "$(resize)"

        ${lib.optionalString (pwd != "") "cd '${pwd}' 2>/dev/null"}
        ${lib.optionalString (term != "") "export TERM='${term}'"}
        ${lib.optionalString (path != "") "export PATH='${path}:$PATH'"}
      '';
    };

    networking.firewall.enable = lib.mkVMOverride false;
  };
}
