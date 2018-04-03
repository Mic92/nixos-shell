{ pkgs, ...}: {
  boot.kernelPackages = pkgs.linuxPackages_latest;
  services.openssh.enable = true;
}
