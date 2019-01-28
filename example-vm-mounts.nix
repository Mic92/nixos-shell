{ pkgs, ...}: {
  boot.kernelPackages = pkgs.linuxPackages_latest;
  services.openssh.enable = true;

  nixos-shell.mounts.extraMounts."/mnt/nixos-shell" = {
    target = ./.;
    cache = "none";
  };
}
