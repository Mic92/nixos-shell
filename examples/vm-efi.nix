{ config, lib, pkgs, ... }:
{
  virtualisation.qemu.options = [ "-bios" "${pkgs.OVMF.fd}/FV/OVMF.fd" ];
}
