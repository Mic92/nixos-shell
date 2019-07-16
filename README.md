# nixos-shell

* Spawns a headless qemu virtual machines based on a `vm.nix` nixos module in the current working directory.
* Mounts `$HOME` and the user's nix profile into the virtual machine
* Provides console access in the same terminal window

Example `vm.nix`:

```nix
{ pkgs, ... }: {
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
```

## How to install

Best you use the [NUR Package Repository](https://github.com/nix-community/NUR#installation)
and install `repos.mic92.nixos-shell`.

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

Type `Ctrl-a x` to exit the virtual machine.

You can also run the `poweroff` command in the virtual machine console:

```console
$vm> poweroff
```

Or switch to qemu console with `Ctrl-a c` and type:

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

### SSH login

Your keys are used to enable passwordless login for the root user.
At the moment only `~/.ssh/id_rsa.pub`, `~/.ssh/id_ecdsa.pub` and `~/.ssh/id_ed25519.pub` are
added automatically. Use `users.users.root.openssh.authorizedKeys.keyFiles` to add more.

## RAM

By default qemu will allow at most 500MB of RAM, this can be increased using `virtualisation.memorySize`.

```nix
{ virtualisation.memorySize = "1024M"; }
```

## CPUs

To increase the CPU count use `virtualisation.cores` (defaults to 1):

```nix
{ virtualisation.cores = 2; }
```

## Graphics/Xserver

To use graphical applications, add the `virtualisation.graphics` NixOS option (see `examples/vm-graphics.nix`).

## Firewall

By default for user's convenience `nixos-shell` does not enable a firewall.
This can be overridden by:

```nix
{ networking.firewall.enable = true; }
```

## Shared folders

To mount anywhere inside the virtual machine, use the `nixos-shell.mounts.extraMounts` option.

```nix
{
  nixos-shell.mounts.extraMounts = {
    # simple USB stick sharing
    "/media" = /media;

    # override options for each mount
    "/var/www" = {
      target = ./src;
      cache = "none";
    };
  };
}
```

You can further configure the default mount settings:

```nix
{
  nixos-shell.mounts = {
    mountHome = false;
    mountNixProfile = false;
    cache = "none"; # default is "loose"
  };
}
```

Available cache modes are documented in the [9p kernel module].

## More configuration

Have a look at the [virtualisation] options NixOS provides.

[virtualisation]: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/qemu-vm.nix
[9p kernel module]: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/Documentation/filesystems/9p.txt
