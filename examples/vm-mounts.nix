{
  nixos-shell.mounts = {
    cache = "never";
    extraMounts = {
      "/mnt/examples" = ./.;

      "/mnt/nixos-shell" = {
        target = ./..;
        readOnly = true;
      };
    };
  };
}
