# nixos-shell

* Spawns a headless qemu virtual machines based on a `vm.nix` nixos module in the current working directory.
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

## Start a virtual machine

To start a vm use:

```console
$ nixos-shell
```

In this case `nixos-shell` will read `vm.nix` in the current directory.
Instead of `vm.nix`, `nixos-shell` also accepts other modules on the command line.

```console
$ nixos-shell some-nix-module.nix
```

## Terminating the virtual machine

To quit a virtual machine run the `poweroff` command in the virtual machine console

```console
$vm> poweroff
```

Or type in the qemu console (if tmux mode is used).

```console
(qemu) quit
```

## Port forwarding

To forward ports from the virtual machine to the host, override the
`QEMU_NET_OPTS` environment variable. 
In this example the tcp port 2222 on the host is forwarded to port 22 in the virtual
machine:

```console
$ QEMU_NET_OPTS="hostfwd=tcp::2222-:22" nixos-shell
```

## RAM

By default qemu will allow at most 362MB of RAM, this can be increase using
`QEMU_OPTS`.

```console
$ QEMU_OPTS="-m 1024" nixos-shell
```

## CPUs

To increase the CPU count use the `--smp` qemu flag (defaults to 1):

```console
$ QEMU_OPTS="--smp 2" nixos-shell
```

## Firewall:

By default for user's convenience `nixos-shell` does not enable a firewall.
This can be overridden by:

```nix
{ lib, ...}: {
 networking.firewall.enable = lib.mkForce true;
}
```
