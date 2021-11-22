INSTALL ?= install
NIXOS_SHELL ?= $(shell nix-build --no-out-link default.nix)/bin/nixos-shell

all:

test:
	$(NIXOS_SHELL) examples/vm.nix

test-resources:
	$(NIXOS_SHELL) examples/vm-resources.nix

test-forward:
	$(NIXOS_SHELL) examples/vm-forward.nix

test-graphics:
	$(NIXOS_SHELL) examples/vm-graphics.nix

test-mounts:
	$(NIXOS_SHELL) examples/vm-mounts.nix

test-efi:
	$(NIXOS_SHELL) examples/vm-efi.nix

install:
	$(INSTALL) -D bin/nixos-shell $(DESTDIR)$(PREFIX)/bin/nixos-shell
	$(INSTALL) -D share/modules/nixos-shell.nix $(DESTDIR)$(PREFIX)/share/modules/nixos-shell.nix
	$(INSTALL) -D share/modules/nixos-shell-config.nix $(DESTDIR)$(PREFIX)/share/modules/nixos-shell-config.nix
	$(INSTALL) -D share/nixos-shell.nix $(DESTDIR)$(PREFIX)/share/nixos-shell.nix
