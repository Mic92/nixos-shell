{ pkgs, ... }: {
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keyFiles = [ "${builtins.getEnv "HOME"}/.ssh/id_rsa.pub" ];
}
