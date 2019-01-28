{ pkgs, ... }: {
  nixos-shell.mounts.extraMounts."/mnt/nixos-shell" = {
    target = ./..;
    cache = "none";
  };
}
