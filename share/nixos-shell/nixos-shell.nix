{ lib, config, pkgs, ... }:

let
  home = builtins.getEnv "HOME";
  user = builtins.getEnv "USER";
  pwd = builtins.getEnv "PWD";
  shell = builtins.getEnv "QEMU_SHELL";
  path = builtins.getEnv "QEMU_PATH";
  nixos_config = builtins.getEnv "QEMU_NIXOS_CONFIG";
  term = builtins.getEnv "TERM";
  mounts = builtins.getEnv "_mounts";
in {
  users.extraUsers.root = {
    # Allow the user to login as root without password.
    initialHashedPassword = "";
    shell = pkgs.${shell} or pkgs.bashInteractive;
    home = lib.mkVMOverride (if home != "" then home else "/root");
  };
  services.mingetty.helpLine = ''
    Log in as "root" with an empty password.
  '';

  # build-vm overrides our filesystem settings in nixos-config
  # cache=loose -> bad idea? Well, at least it is fast!1!!
  boot.initrd.postMountCommands = ''
    mkdir -p $targetRoot/home
    mount -t 9p home $targetRoot/home -o trans=virtio,version=9p2000.L,cache=loose
    ${lib.optionalString (user != "") ''
      mkdir -p $targetRoot/nix/var/nix/profiles/per-user/${user}/profile/
      mount -t 9p nixprofile $targetRoot/nix/var/nix/profiles/per-user/${user}/profile/ -o trans=virtio,version=9p2000.L,cache=loose
    ''}

    export targetRoot
    ${pkgs.bash}/bin/bash <<\EOF
    eval "${mounts}"
    for mount_tag in "''${!mounts[*]}"; do
      target=$targetRoot/"''${mounts[$mount_tag]}"
      mkdir -p "$target"
      mount -t 9p $mount_tag "$target" -o trans=virtio,version=9p2000.L,cache=loose
    done
    EOF
  '';
  environment.loginShellInit = ''
    # fix terminal size
    eval "$(${pkgs.xterm}/bin/resize)"

    ${lib.optionalString (pwd != "") "cd '${pwd}' 2>/dev/null"}
    ${lib.optionalString (term != "") "export TERM='${term}'"}
    ${lib.optionalString (path != "") "export PATH=${path}:$PATH"}
  '';

  systemd.services."serial-getty@ttyS0".enable = true;
  networking.firewall.enable = false;

  imports = lib.optional (nixos_config != "") nixos_config;
}
