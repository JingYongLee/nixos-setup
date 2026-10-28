.PHONY: provision bootstrap install verify

# Guest IP: match the domain's NIC MAC against libvirt's DHCP leases.
# Works both on the installer (hostname "nixos") and the installed system.
# Run on the hypervisor host, where the repo is cloned at
# ~/workspace/nixos-setup (the old nixos-setup-legacy checkout must be
# renamed aside first).
GUEST_IP = $(shell virsh --connect qemu:///system domiflist vm | awk '/virtio/{print $$5}' | head -1 | xargs -I{} sh -c 'virsh --connect qemu:///system net-dhcp-leases default | grep {} | awk "{print \$$5}" | cut -d/ -f1')

# Provision a fresh vm domain and boot the minimal installer ISO.
# The predecessor nixvm domain is left untouched (known-good baseline).
provision:
	bash scripts/provision-vm.sh

# Drop the host SSH key onto the installer's autologin console.
bootstrap:
	python3 scripts/bootstrap-console.py

# nixos-anywhere: partition, install, reboot.
install:
	@test -n "$(GUEST_IP)" || { echo "no lease for vm found"; exit 1; }; \
	echo "installing to root@$(GUEST_IP)"; \
	ssh-keygen -R $(GUEST_IP) 2>/dev/null; \
	nix run github:nix-community/nixos-anywhere -- --flake .#vm root@$(GUEST_IP)

# Smoke checks inside the installed guest: the desktop pieces exist and
# the greeter is up. The full trial gate (binds, theme round-trip,
# media keys, lock/wake) is a checklist, not a make target.
verify:
	@test -n "$(GUEST_IP)" || { echo "no lease for vm found"; exit 1; }; \
	ssh-keygen -R $(GUEST_IP) 2>/dev/null; \
	ssh -o StrictHostKeyChecking=accept-new jingyonglee@$(GUEST_IP) sh -c '\
		systemctl is-active display-manager.service && \
		ls /run/current-system/sw/share/wayland-sessions/ | grep -q omarchy && \
		command -v omarchy && command -v nixarchy && \
		ghostty --version | head -1 && \
		nvim --version | head -1 && \
		opencode --version'
