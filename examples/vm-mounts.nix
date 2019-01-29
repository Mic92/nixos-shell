{ pkgs, ... }: {
  nixos-shell.mounts.extraMounts = {
    "/mnt/examples" = ./.;

    "/mnt/nixos-shell" = {
      target = ./..;
      cache = "none";
    };
  };
}
