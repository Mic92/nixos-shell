{ lib, options, config, pkgs, ... }:

let
  cfg = config.nixos-shell;
  home = builtins.getEnv "HOME";
  mkVMDefault = lib.mkOverride 900;
  foreignVM = options.virtualisation.host.pkgs.isDefined && config.virtualisation.host.pkgs.stdenv.hostPlatform != pkgs.stdenv.hostPlatform;
in {
  config =
    let
      user = builtins.getEnv "USER";
      shell' = builtins.baseNameOf (builtins.getEnv "SHELL");

      # fish seems to do funky stuff: https://github.com/Mic92/nixos-shell/issues/42
      shell = if shell' == "fish" then "bash" else shell';
      # Enable the module of the user's shell for some sensible defaults.
      maybeSetShell = lib.optional (options.programs ? ${shell}.enable && shell != "bash") {
        programs.${shell}.enable = mkVMDefault true;
      };

      # Newer single-user/XDG installs keep profiles under ~/.local/state, older
      # multi-user installs use /nix/var/nix/profiles/per-user. Pick whichever
      # exists on the host so the guest sees the same profile.
      nixProfileCandidates = [
        "${home}/.local/state/nix/profiles"
        "/nix/var/nix/profiles/per-user/${user}/profile"
      ];
      nixProfile = lib.findFirst builtins.pathExists null nixProfileCandidates;
      exportNixProfile = cfg.mounts.mountNixProfile && nixProfile != null;
    in
    lib.mkMerge (maybeSetShell ++ [
      (lib.mkIf (pkgs ? ${shell}) {
        users.extraUsers.root.shell = mkVMDefault pkgs.${shell};
      })

      (
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

        services.getty.helpLine = ''
          If you are connect via serial console:
          Type Ctrl-a c to switch to the qemu console
          and `quit` to stop the VM.
        '';
        services.getty.autologinUser = "root";

        virtualisation = {
          graphics = mkVMDefault false;
          memorySize = mkVMDefault 700;

          # virtiofsd shares the guest's memory, thus it requires the memory to
          # be backed by shared memory.
          qemu.enableSharedMemory = mkVMDefault true;

          qemu.consoles = lib.mkIf (!config.virtualisation.graphics) [ "tty0" "hvc0" ];

          qemu.options =
            lib.optionals (!config.virtualisation.graphics) [
              "-serial null"
              "-device virtio-serial"
              "-chardev stdio,mux=on,id=char0,signal=off"
              "-mon chardev=char0,mode=readline"
              "-device virtconsole,chardev=char0,nr=0"
            ];

          # Share the host directories with the guest via virtiofs.
          # The qemu-vm module turns these into `virtualisation.fileSystems`
          # entries (fsType = "virtiofs", neededForBoot = true).
          sharedDirectories =
            (lib.optionalAttrs cfg.mounts.mountHome {
              home = {
                source = home;
                target = home;
                writable = !cfg.mounts.mountHomeReadOnly;
              };
            }) //
            (lib.optionalAttrs exportNixProfile {
              nixprofile = {
                source = nixProfile;
                target = nixProfile;
                writable = true;
              };
            }) //
            (lib.mapAttrs' (name: mount: lib.nameValuePair mount.tag {
              source = builtins.toString mount.target;
              target = name;
              writable = !mount.readOnly;
            }) cfg.mounts.extraMounts);
        };

        # avoid leaking incompatible host binaries into the VM
        system.activationScripts.shadow-nix-profile = lib.mkIf foreignVM (lib.stringAfter [ "specialfs" "users" "groups" ] ''
          mkdir -p ${lib.escapeShellArg home}/.nix-profile/
          mount --bind ${config.system.path} ${lib.escapeShellArg home}/.nix-profile/
        '');

        environment = {
          systemPackages = with pkgs; [
            xterm # for resize command
          ];

          extraSetup = lib.optionalString cfg.terminfo.fixFSCaseConflicts ''
            nixosShell::symlinkToDir() (
              # this function runs in a subshell to make shopt local to this function
              shopt -s nullglob

              local target="$1"

              if ! [[ -L "$target" && -d "$target" ]]; then
                return
              fi

              local linkTo="$(readlink "$target")"
              rm "$target"
              mkdir "$target"

              local files=( "$linkTo/"{.,}* )
              if (( ''${#files[@]} > 0 )); then
                cp -s "''${files[@]}" "$target/"
              fi
            )

            nixosShell::fixTerminfoFSCaseConflicts() {
              nixosShell::symlinkToDir "$out"
              nixosShell::symlinkToDir "$out/share"
              nixosShell::symlinkToDir "$out/share/terminfo"
              pushd "$out/share/terminfo"

              local c
              for c in {a..z}; do
                if [[ -d "$c" && -d "''${c@U}" && ! "$c" -ef ''${c@U} ]]; then
                  nixosShell::symlinkToDir "''${c@U}"
                  cp "$c/"* "''${c@U}/"
                fi
              done

              popd
            }

            nixosShell::fixTerminfoFSCaseConflicts
          '';

          loginShellInit =
            let
              pwd = builtins.getEnv "PWD";
              term = builtins.getEnv "TERM";
              path = builtins.getEnv "PATH";
            in
            ''
              # if terminal with stdout, fix terminal size
              if [ -t 1 ]; then eval "$(resize)"; fi

              ${lib.optionalString (pwd != "") "cd '${pwd}' 2>/dev/null"}
              ${lib.optionalString (term != "") "export TERM='${term}'"}
              ${lib.optionalString (cfg.inheritPath && path != "") "export PATH=\"${path}:$PATH\""}
            '';
        };

        networking.firewall.enable = mkVMDefault false;

        # Nix operations fail on flakes in Git repositories located on the host filesystem due to
        # differing UIDs. Adjusting Git settings allows Nix to work with these host repositories.
        programs.git.config.safe.directory = mkVMDefault "*";
        environment.etc.gitconfig = lib.mkIf (!config.programs.git.enable) {
          text = lib.concatMapStringsSep "\n" lib.generators.toGitINI config.programs.git.config;
        };
      }
    ]);
}
