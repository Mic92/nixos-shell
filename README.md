# nixos-shell

* Spawns a headless vm based on a `vm.nix` file in the current directory.
* Mounts `$HOME` and the user's nix profile into the container
* No ugly qemu SDL window, no serial console with incorrect terminal dimension.
* If a tmux session is available, the console spawns in a new tmux pane, 
  while the qemu interface starts current active pane

Example `vm.nix`:

```nix
{ pkgs, ...}: {
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
```

## USAGE

Start a vm:

```console
$ nixos-shell
```

or

```console
$ nixos-shell some-nix-module.nix
```

Quit the vm:

```console
$vm> poweroff
```

or in the qemu console:

```console
(qemu) quit
```

Forward port 2222 on the host to port 22 in the vm:

```console
$ QEMU_NET_OPTS="hostfwd=tcp::2222-:22" nixos-shell
```

More RAM (in megabyte; defaults to 362MB):

```console
$ QEMU_OPTS="-m 1024" nixos-shell
```

More CPUs (defaults to 1):

```console
$ QEMU_OPTS="--smp 2" nixos-shell
```

Re-enable firewall:

By default for user's convenience `nixos-shell` does not enable a firewall.
This can be overridden by:

```nix
{ lib, ...}: {
 networking.firewall.enable = lib.mkForce true;
}
```
