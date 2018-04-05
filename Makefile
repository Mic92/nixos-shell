INSTALL ?= install
NIXOS_SHELL ?= $(shell nix-build --no-out-link default.nix)/bin/nixos-shell

all:

test:
	QEMU_NET_OPTS="hostfwd=tcp::2222-:22" QEMU_OPTS="--smp 2 -m 1024" $(NIXOS_SHELL) example-vm.nix

test-graphics:
	QEMU_OPTS="-sdl" $(NIXOS_SHELL) example-vm.nix

install:
	$(INSTALL) -D bin/nixos-shell $(DESTDIR)$(PREFIX)/bin/nixos-shell
	$(INSTALL) -D share/nixos-shell/nixos-shell.nix $(DESTDIR)$(PREFIX)/share/nixos-shell/nixos-shell.nix
