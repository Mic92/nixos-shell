{ pkgs, ... }: {
  services.xserver.enable = true;
  virtualisation.graphics = true;
}
