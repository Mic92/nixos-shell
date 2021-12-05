{ lib, options, config, pkgs, ... }:

let
  cfg = config.nixos-shell;

  mkVMDefault = lib.mkOverride 900;
in {
  config =
    let
      user = builtins.getEnv "USER";
      shell' = builtins.baseNameOf (builtins.getEnv "SHELL");

      # fish seems to do funky stuff: https://github.com/Mic92/nixos-shell/issues/42
      shell = if shell' == "fish" then "bash" else shell';
    in
    lib.mkMerge [
      # Enable the module of the user's shell for some sensible defaults.
      (lib.mkIf (options.programs ? ${shell}.enable && shell != "bash") {
        programs.${shell}.enable = mkVMDefault true;
      })

      (lib.mkIf (pkgs ? ${shell}) {
        users.extraUsers.root.shell = mkVMDefault pkgs.${shell};
      })

      (
        let
          home = builtins.getEnv "HOME";
        in
        lib.mkIf (home != "" && cfg.mounts.mountHome) {
          users.extraUsers.root.home = lib.mkVMOverride home;
        }
      )

      # Allow passwordless ssh login with the user's key if it exists.
      (
        let
          keys = map (key: "${builtins.getEnv "HOME"}/.ssh/${key}")
            [ "id_rsa.pub" "id_ecdsa.pub" "id_ed25519.pub" ];
        in
        {
          users.users.root.openssh.authorizedKeys.keyFiles = lib.filter builtins.pathExists keys;
        }
      )

      {
        # Allow the user to login as root without password.
        users.extraUsers.root.initialHashedPassword = "";

        # see https://wiki.qemu.org/Documentation/9psetup#Performance_Considerations
        # == 100M
        # FIXME? currently 500K seems to be the limit?
        virtualisation.msize = mkVMDefault 104857600;

        services =
          let
            service = if lib.versionAtLeast (lib.versions.majorMinor lib.version) "20.09" then "getty" else "mingetty";
          in
          {
            ${service}.helpLine = ''
              Log in as "root" with an empty password.
              If you are connect via serial console:
              Type Ctrl-a c to switch to the qemu console
              and `quit` to stop the VM.
            '';
          };

        virtualisation = {
          graphics = mkVMDefault false;
          memorySize = mkVMDefault 700;

          qemu.consoles = lib.mkIf (!config.virtualisation.graphics) [ "tty0" "hvc0" ];

          qemu.options =
            let
              nixProfile = "/nix/var/nix/profiles/per-user/${user}/profile/";
            in
            lib.optionals (!config.virtualisation.graphics) [
              "-serial null"
              "-device virtio-serial"
              "-chardev stdio,mux=on,id=char0,signal=off"
              "-mon chardev=char0,mode=readline"
              "-device virtconsole,chardev=char0,nr=0"
            ] ++
            lib.optional cfg.mounts.mountHome "-virtfs local,path=/home,security_model=none,mount_tag=home" ++
            lib.optional (cfg.mounts.mountNixProfile && builtins.pathExists nixProfile) "-virtfs local,path=${nixProfile},security_model=none,mount_tag=nixprofile" ++
            lib.mapAttrsToList (target: mount: "-virtfs local,path=${builtins.toString mount.target},security_model=none,mount_tag=${mount.tag}") cfg.mounts.extraMounts;
        };

        # build-vm overrides our filesystem settings in nixos-config
        boot.initrd.postMountCommands =
          (lib.optionalString cfg.mounts.mountHome ''
            mkdir -p $targetRoot/home/
            mount -t 9p home $targetRoot/home/ -o trans=virtio,version=9p2000.L,cache=${cfg.mounts.cache},msize=${toString config.virtualisation.msize}
          '') +
          (lib.optionalString (user != "" && cfg.mounts.mountNixProfile) ''
            mkdir -p $targetRoot/nix/var/nix/profiles/per-user/${user}/profile/
            mount -t 9p nixprofile $targetRoot/nix/var/nix/profiles/per-user/${user}/profile/ -o trans=virtio,version=9p2000.L,cache=${cfg.mounts.cache},msize=${toString config.virtualisation.msize}
          '') +
          builtins.concatStringsSep " " (lib.mapAttrsToList
            (target: mount: ''
              mkdir -p $targetRoot/${target}
              mount -t 9p ${mount.tag} $targetRoot/${target} -o trans=virtio,version=9p2000.L,cache=${mount.cache},msize=${toString config.virtualisation.msize}
            '')
            cfg.mounts.extraMounts);

        environment = {
          systemPackages = with pkgs; [
            xterm # for resize command
          ];

          loginShellInit =
            let
              pwd = builtins.getEnv "PWD";
              term = builtins.getEnv "TERM";
              path = builtins.getEnv "PATH";
            in
            ''
              # fix terminal size
              eval "$(resize)"

              ${lib.optionalString (pwd != "") "cd '${pwd}' 2>/dev/null"}
              ${lib.optionalString (term != "") "export TERM='${term}'"}
              ${lib.optionalString (path != "") "export PATH=\"${path}:$PATH\""}
            '';
        };

        networking.firewall.enable = mkVMDefault false;
      }
    ];
}
