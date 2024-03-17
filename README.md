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

`nixos-shell` is available in nixpkgs.

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

You can also start a vm from a flake's `nixosConfigurations` or `nixosModules` output using the `--flake` flag.

```console
$ nixos-shell --flake github:Mic92/nixos-shell#vm-forward
```

This will run the `vm-forward` example.

> Note: `nixos-shell` must be able to extend the specified system configuration with [certain modules](share/modules).
>
> If your version of `nixpkgs` provides the `extendModules` function on system configurations, `nixos-shell` will use it to inject the required modules; no additional work on your part is needed.
>
> If your version of `nixpkgs` **does not** provide `extendModules`, you must make your system configurations overridable with `lib.makeOverridable` to use them with `nixos-shell`:
>```nix
>{
>  nixosConfigurations = let
>    lib = nixpkgs.lib;
>  in {
>    vm = lib.makeOverridable lib.nixosSystem {
>      # ...
>    };
>  };
>}
>```
> Specifying a non-overridable system configuration will cause `nixos-shell` to abort with a non-zero exit status.

When using the `--flake` flag, if no attribute is given, `nixos-shell` tries the following flake output attributes:
- `packages.<system>.nixosConfigurations.<vm>`
- `nixosConfigurations.<vm>`
- `nixosModules.<vm>`

If an attribute _name_ is given, `nixos-shell` tries the following flake output attributes:
- `packages.<system>.nixosConfigurations.<name>`
- `nixosConfigurations.<name>`
- `nixosModules.<name>`


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

To forward ports from the virtual machine to the host, use the
`virtualisation.forwardPorts` NixOS option.
See `examples/vm-forward.nix` where the ssh server running on port 22 in the
virtual machine is made accessible through port 2222 on the host.

The same can be also achieved by using the `QEMU_NET_OPTS` environment variable.

```console
$ QEMU_NET_OPTS="hostfwd=tcp::2222-:22" nixos-shell
```

### SSH login

Your keys are used to enable passwordless login for the root user.
At the moment only `~/.ssh/id_rsa.pub`, `~/.ssh/id_ecdsa.pub` and `~/.ssh/id_ed25519.pub` are
added automatically. Use `users.users.root.openssh.authorizedKeys.keyFiles` to add more.

*Note: sshd is not started by default. It can be enabled by setting
`services.openssh.enable = true`.*

## Bridge Network

QEMU is started with user mode network by default. To use bridge network instead, 
set `virtualisation.qemu.networkingOptions` to something like
`[ "-nic bridge,br=br0,model=virtio-net-pci,mac=11:11:11:11:11:11,helper=/run/wrappers/bin/qemu-bridge-helper" ]`. `/run/wrappers/bin/qemu-bridge-helper` is a NixOS specific
path for qemu-bridge-helper on other Linux distributions it will be different.
QEMU needs to be installed on the host to get `qemu-bridge-helper` with setuid bit 
set - otherwise you will need to start VM as root. On NixOS this can be achieved using
`virtualisation.libvirtd.enable = true;`


## RAM

By default qemu will allow at most 500MB of RAM, this can be increased using `virtualisation.memorySize` (size in megabyte).

```nix
{ virtualisation.memorySize = 1024; }
```

## CPUs

To increase the CPU count use `virtualisation.cores` (defaults to 1):

```nix
{ virtualisation.cores = 2; }
```

## Hard drive

To increase the size of the virtual hard drive, i. e. to 20 GB (see [virtualisation] options at bottom, defaults to 512M):

```nix
{ virtualisation.diskSize = 20 * 1024; }
```

Notice that for this option to become effective you may also need to delete previous block device files created by qemu (`nixos.qcow2`).

Notice that changes in the nix store are written to an overlayfs backed by tmpfs rather than the block device
that is configured by `virtualisation.diskSize`. This tmpfs can be disabled however by using:

```nix
{ virtualisation.writableStoreUseTmpfs = false; }
```

This option is recommend if you plan to use nixos-shell as a remote builder.

## Graphics/Xserver

To use graphical applications, add the `virtualisation.graphics` NixOS option (see `examples/vm-graphics.nix`).

## Firewall

By default for user's convenience `nixos-shell` does not enable a firewall.
This can be overridden by:

```nix
{ networking.firewall.enable = true; }
```

## Mounting physical disks

There does not exists any explicit options right now but 
one can use either the `$QEMU_OPTS` environment variable
or set `virtualisation.qemu.options` to pass the right qemu
command line flags:

```nix
{
  # /dev/sdc also needs to be read-writable by the user executing nixos-shell
  virtualisation.qemu.options = [ "-hdc" "/dev/sdc" ];
}
```


## Boot with efi

``` nix
{ virtualisation.qemu.options = [ "-bios" "${pkgs.OVMF.fd}/FV/OVMF.fd" ]; }
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

## Disable KVM

In many cloud environments KVM is not available and therefore nixos-shell will fail with:  
`CPU model 'host' requires KVM`.  
In newer versions of nixpkgs this has been fixed by falling back to [emulation](https://github.com/NixOS/nixpkgs/pull/95956).
In older version one can set the `virtualisation.qemu.options` or set the environment variable `QEMU_OPTS`:

```bash
export QEMU_OPTS="-cpu max"
nixos-shell
```

A full list of supported qemu cpus can be obtained by running `qemu-kvm -cpu help`.

## Channels/NIX_PATH

By default VMs will have a NIX_PATH configured for nix channels but no channel are downloaded yet.
To avoid having to download a nix-channel every time the VM is reset, you can use the following nixos configuration:

```nix
{...}: {
  nix.nixPath = [
    "nixpkgs=${pkgs.path}"
  ];
}
```

This will add the nixpkgs that is used for the VM in the NIX_PATH of login shell.

## Embedding nixos-shell in your own nixos-configuration

Instead of using the cli, it's also possible to include the `nixos-shell` NixOS module in your own NixOS configuration.

Add this to your `flake.nix`:

```nix
{
  inputs.nixos-shell.url = "github:Mic92/nixos-shell";
}
```

And this to your nixos configuration defined in your flake:

```nix
{
  imports = [ inputs.nixos-shell.nixosModules.nixos-shell ];
}
```

Afterwards you can start your nixos configuration with nixos-shell with one of the two following variants:

For the pure version (doesn't set SHELL or mount /home):

```
nix run .#nixosConfigurations.<yourmachine>.config.system.build.nixos-shell
```

Or for a version closer to `nixos-shell`:

```
nix run .#nixosConfigurations.<yourmachine>.config.system.build.nixos-shell
```

## More configuration

Have a look at the [virtualisation] options NixOS provides.

[virtualisation]: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/qemu-vm.nix
[9p kernel module]: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/Documentation/filesystems/9p.rst
